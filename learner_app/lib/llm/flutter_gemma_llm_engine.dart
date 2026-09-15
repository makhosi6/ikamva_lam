import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../debug/agent_debug_log.dart';
import '../state/settings_store.dart';
import 'android_hf_download_setup.dart';
import 'gemma4_ondevice_variant.dart';
import 'gemma_hf_model_download_service.dart';
import 'gemma_inference_defaults.dart';
import 'gemma_model_config.dart';
import 'hf_install_error_format.dart';
import 'huggingface_auth_token_store.dart';
import 'llm_engine.dart';
import 'llm_exceptions.dart';
import 'llm_generate_request.dart';
import 'llm_limits.dart';
import 'llm_output_filters.dart';
import 'model_cache_checker.dart';
import 'model_diagnostics.dart';
import 'model_prepare_config.dart';
import 'model_prepare_prefs.dart';
import 'native_llm_platform.dart';
import 'on_device_gemma_variant.dart';
import 'streaming_llm_capability.dart';

/// Upper bound for native GPU weight upload / delegate setup.
const Duration _kGpuModelOpenTimeout = Duration(seconds: 120);

/// Mutable callbacks so [LlmService.configure] can attach progress UI without
/// disposing an in-flight [FlutterGemmaLlmEngine] (avoids overlapping native
/// loads when the hub attaches hooks after warm-up starts).
final class LlmInstallUiHooks {
  void Function(int installPercent)? onInstallProgress;
  void Function(String phase, String message, int? percent)? onLifecycle;
}

/// iOS Metal / TFLite GPU delegate failed — the weights file is often fine; use
/// CPU backend or **Low RAM profile** (Settings). Do **not** treat as corrupt zip.
bool gemmaErrorLooksLikeGpuMetalDelegateFailure(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('modifygraphwithdelegate') ||
      s.contains('gpu_delegate') ||
      s.contains('llm_litert_metal') ||
      s.contains('litert_metal_executor') ||
      s.contains('tflitegpudelegate') ||
      (s.contains('metal') && s.contains('delegate'));
}

/// GPU resource exhaustion errors: buffer timeout, memory pressure, or GPU stalls.
bool gemmaErrorLooksLikeGpuResourceExhaustion(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('queue_buffer_timeout') ||
      s.contains('gpu completion') ||
      s.contains('queue buffer') ||
      s.contains('lost connection') ||
      s.contains('opengl') ||
      s.contains('opencl') ||
      s.contains('gpu stall') ||
      s.contains('memory pressure') ||
      (s.contains('timeout') && (s.contains('gpu') || s.contains('render')));
}

/// True when LiteRT / MediaPipe failed to read the **artifact** as a zip.
bool gemmaErrorLooksLikeInvalidTaskArchive(Object error) {
  if (gemmaErrorLooksLikeGpuMetalDelegateFailure(error)) return false;
  final s = error.toString().toLowerCase();
  return s.contains('zip archive') ||
      s.contains('unable to open zip') ||
      (s.contains('unable to open') && s.contains('zip'));
}

GemmaHfModelDownloadService _hfServiceForVariant(OnDeviceGemmaVariant v) {
  return GemmaHfModelDownloadService.forVariant(v);
}

/// Pure predicate behind [shouldUseFlutterGemmaEngine] (Requirements 10.2, 11.4).
bool computeShouldUseFlutterGemmaEngine({
  required bool isWeb,
  required bool isAndroid,
  required bool isIos,
}) {
  if (isWeb) return false;
  return isAndroid || isIos;
}

Future<String> _documentsModelBaseDir() async {
  final directory = await getApplicationDocumentsDirectory();
  final p = directory.path;
  return p.contains('/data/user/0/')
      ? p.replaceFirst('/data/user/0/', '/data/data/')
      : p;
}

/// True when the on-disk weights for the **selected** variant exist.
Future<bool> flutterGemmaActiveInferenceInstalled(
  OnDeviceGemmaVariant variant,
) async {
  return _hfServiceForVariant(variant).isPluginModelInstalled();
}

/// Deletes known weight filenames under app documents and legacy plugin ids
/// (as filenames) so a bad copy is not reused.
Future<void> purgeGemmaPluginInstallCandidates() async {
  final base = await _documentsModelBaseDir();
  final ids = <String>{
    for (final v in OnDeviceGemmaVariant.values) ...[
      ...GemmaModelConfig.pluginUninstallCandidateIdsFor(
        GemmaModelConfig.artifactFor(v).url,
      ),
      GemmaModelConfig.artifactFor(v).filename,
    ],
    'ikamva_ondevice_model',
    'bundled_gemma.task',
  };
  for (final id in ids) {
    if (id.isEmpty) continue;
    try {
      final f = File('$base/$id');
      if (f.existsSync()) {
        await f.delete();
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'purge_uninstall',
        message: 'Removed model candidate file',
        data: <String, Object?>{'path': f.path},
      );
      debugPrint('purgeGemmaPluginInstallCandidates: deleted $id');
    } on Object {
      // Missing file — ignore.
    }
  }
}

Future<void> _nativeLoad({
  required String modelPath,
  required int maxTokens,
  required bool preferGpu,
}) async {
  // #region agent log
  agentDebugLog(
    location: 'flutter_gemma_llm_engine.dart:_nativeLoad',
    message: 'native loadModel start',
    hypothesisId: 'H4',
    data: <String, Object?>{
      'preferGpu': preferGpu,
      'modelPath': modelPath,
      'maxTokens': maxTokens,
    },
  );
  // #endregion
  await NativeLlmPlatform.loadModel(<String, Object?>{
    'modelPath': modelPath,
    'maxTokens': maxTokens,
    'preferGpu': preferGpu,
    'supportImage': GemmaModelConfig.activeModelSupportImage,
    'supportAudio': GemmaModelConfig.activeModelSupportAudio,
    'maxNumImages': GemmaModelConfig.activeModelMaxNumImages,
  });
  // #region agent log
  agentDebugLog(
    location: 'flutter_gemma_llm_engine.dart:_nativeLoad',
    message: 'native loadModel end',
    hypothesisId: 'H4',
    data: <String, Object?>{
      'preferGpu': preferGpu,
      'maxTokens': maxTokens,
    },
  );
  // #endregion
}

/// Returns whether downloaded weights can be opened natively (mobile only).
Future<bool> probeFlutterGemmaActiveModelReady(SettingsStore settings) async {
  if (!shouldUseFlutterGemmaEngine) return true;
  if (!await flutterGemmaActiveInferenceInstalled(settings.gemma4OnDeviceVariant)) {
    ModelDiagnostics.instance.log(
      area: 'probe',
      action: 'skip_no_install',
      message:
          'No lesson-helper model on disk yet (finish Download on the setup '
          'screen and Continue, or Settings → Warm up). Probe skipped.',
    );
    return false;
  }
  final path =
      await _hfServiceForVariant(settings.gemma4OnDeviceVariant).getFilePath();
  Future<bool> probe(bool preferGpu) async {
    try {
      ModelDiagnostics.instance.log(
        area: 'probe',
        action: 'open_attempt',
        message: 'Trying native load',
        data: <String, Object?>{'preferGpu': preferGpu},
      );
      await _nativeLoad(
        modelPath: path,
        maxTokens: ModelPrepareConfig.contextMaxTokensFor(settings.lowRamProfile),
        preferGpu: preferGpu,
      ).timeout(
        preferGpu ? _kGpuModelOpenTimeout : const Duration(seconds: 180),
        onTimeout: () => throw TimeoutException('native load'),
      );
      await NativeLlmPlatform.closeModel();
      return true;
    } on Object catch (e) {
      try {
        await NativeLlmPlatform.closeModel();
      } on Object {
        // ignore
      }
      ModelDiagnostics.instance.log(
        area: 'probe',
        action: 'open_failed',
        message: 'Failed native probe load',
        data: <String, Object?>{'preferGpu': preferGpu, 'error': '$e'},
      );
      debugPrint('probeFlutterGemmaActiveModelReady (gpu=$preferGpu): $e');
      return false;
    }
  }

  final multimodal = GemmaModelConfig.activeModelSupportImage ||
      GemmaModelConfig.activeModelSupportAudio;
  final primaryGpu = multimodal
      ? true
      : FlutterGemmaLlmEngine._textOnlyPreferGpuOnHost(settings);
  if (await probe(primaryGpu)) return true;
  if (!multimodal && primaryGpu && await probe(false)) {
    return true;
  }
  // Android defaults to CPU for text-only; if that probe fails, one GPU try for
  // devices where CPU path is broken but GPU works.
  if (!multimodal &&
      Platform.isAndroid &&
      !FlutterGemmaLlmEngine._androidGpuOptInForTextOnly &&
      !primaryGpu &&
      await probe(true)) {
    return true;
  }
  return false;
}

/// On-device inference via **MethodChannel** → native **LiteRT-LM** (Android
/// `.litertlm`) or **MediaPipe GenAI** (iOS). Weights are downloaded to app
/// documents then opened by absolute path.
class FlutterGemmaLlmEngine implements LlmEngine, StreamingLlmCapability {
  FlutterGemmaLlmEngine({
    required SettingsStore settings,
    required LlmInstallUiHooks installUiHooks,
  }) : _settings = settings,
       _hooks = installUiHooks;

  final SettingsStore _settings;
  final LlmInstallUiHooks _hooks;

  GemmaHfModelDownloadService get _service =>
      _hfServiceForVariant(_settings.gemma4OnDeviceVariant);

  void _emit(String phase, String message, [int? percent]) {
    _hooks.onLifecycle?.call(phase, message, percent);
  }

  void _emitProgress(int p) {
    _hooks.onInstallProgress?.call(p);
    _hooks.onLifecycle?.call('progress', 'Transfer: $p%', p.clamp(0, 100));
  }

  void _finishLoaded() {
    _loaded = true;
    unawaited(() async {
      try {
        await ModelPreparePrefs.markPrepareDone(
          installFingerprint: ModelPrepareConfig.installFingerprint(
            _settings.gemma4OnDeviceVariant,
          ),
        );
      } on Object {
        // best-effort prefs
      }
    }());
  }

  bool _loaded = false;
  bool _disposed = false;
  Object? _lastOpenError;

  Future<void>? _ensureLoadedInFlight;

  /// Android: LiteRT **CPU** uses XNNPack; some Gemma graphs hit
  /// `DYNAMIC_UPDATE_SLICE` / executor 786 at inference. After one such failure,
  /// reopen with **GPU** for this engine lifetime (see `NativeLlmBridge` logs).
  bool _androidEscalateLitertToGpu = false;

  int get _contextMaxTokens =>
      ModelPrepareConfig.contextMaxTokensFor(_settings.lowRamProfile);

  static const int _forceCpuBackendIntFlag = int.fromEnvironment(
    'IKAMVA_FORCE_CPU_BACKEND',
    defaultValue: 0,
  );
  static const String _forceCpuBackendStringFlag = String.fromEnvironment(
    'IKAMVA_FORCE_CPU_BACKEND',
    defaultValue: '',
  );
  static const bool _forceCpuBackendBuildFlag = _forceCpuBackendIntFlag != 0 ||
      _forceCpuBackendStringFlag == 'true' ||
      _forceCpuBackendStringFlag == 'TRUE';

  /// Opt-in GPU for **text-only** `.litertlm` on **Android** (default is CPU).
  ///
  /// Heavy OpenCL / EGL init has killed the process on some devices **before**
  /// any Dart error — so GPU-first on Android is unsafe without an explicit
  /// `--dart-define` (see `post_download_crush` / QUEUE_BUFFER_TIMEOUT).
  static const int _androidGpuForTextIntFlag = int.fromEnvironment(
    'IKAMVA_ANDROID_GPU',
    defaultValue: 0,
  );
  static const String _androidGpuForTextStringFlag = String.fromEnvironment(
    'IKAMVA_PREFER_ANDROID_GPU',
    defaultValue: '',
  );
  static bool get _androidGpuOptInForTextOnly =>
      _androidGpuForTextIntFlag != 0 ||
      _androidGpuForTextStringFlag == 'true' ||
      _androidGpuForTextStringFlag == 'TRUE';

  /// Re-open LiteRT with **GPU** after CPU inference hits the XNNPack /
  /// `DYNAMIC_UPDATE_SLICE` / executor **786** path.
  ///
  /// **Default off:** NDJSON session **669518** — GPU `loadModel` killed the
  /// process mid-init on a MIUI device (no `native loadModel end`). Enable only
  /// with `--dart-define=IKAMVA_ESCALATE_LITERT_CPU_FAIL_TO_GPU=1` if you accept
  /// that risk.
  static const int _escalateCpuInferFailToGpuIntFlag = int.fromEnvironment(
    'IKAMVA_ESCALATE_LITERT_CPU_FAIL_TO_GPU',
    defaultValue: 0,
  );
  static const String _escalateCpuInferFailToGpuStringFlag =
      String.fromEnvironment(
    'IKAMVA_ESCALATE_LITERT_CPU_FAIL_TO_GPU',
    defaultValue: '',
  );
  static bool get _allowEscalateCpuInferFailToGpu =>
      _escalateCpuInferFailToGpuIntFlag != 0 ||
      _escalateCpuInferFailToGpuStringFlag == 'true' ||
      _escalateCpuInferFailToGpuStringFlag == 'TRUE';

  static bool _textOnlyPreferGpuOnHost(SettingsStore settings) {
    if (_forceCpuBackendBuildFlag) return false;
    if (Platform.isAndroid && !_androidGpuOptInForTextOnly) {
      // Android without explicit GPU opt-in → always CPU.
      return false;
    }
    if (Platform.isAndroid) {
      // Android WITH GPU opt-in: honour the flag regardless of RAM profile.
      // On Android, [SettingsStore.lowRamProfile] controls the KV-cache token
      // count (256 vs 512 — see [ModelPrepareConfig.contextMaxTokensFor]),
      // NOT the compute backend. Letting lowRamProfile disable GPU here means
      // the tier-3 Low RAM retry in [NativeLlmChatController] accidentally
      // falls back to CPU even when IKAMVA_PREFER_ANDROID_GPU=true, causing
      // the same XNNPack DYNAMIC_UPDATE_SLICE failure it was trying to escape.
      return true;
    }
    // iOS / desktop: Low RAM mode uses CPU to reduce GPU memory pressure.
    return !settings.lowRamProfile;
  }

  static bool get _multimodalRequiresGpu =>
      GemmaModelConfig.activeModelSupportImage ||
      GemmaModelConfig.activeModelSupportAudio;

  bool get _preferGpu {
    if (_multimodalRequiresGpu) {
      if (_forceCpuBackendBuildFlag || _settings.lowRamProfile) {
        debugPrint(
          'FlutterGemmaLlmEngine: CPU-only overrides ignored for multimodal '
          'LiteRT (vision/audio encoder requires GPU).',
        );
      }
      return true;
    }
    if (_forceCpuBackendBuildFlag) return false;
    return _textOnlyPreferGpuOnHost(_settings);
  }

  /// Effective backend for [NativeLlmBridge] when
  /// [IKAMVA_ESCALATE_LITERT_CPU_FAIL_TO_GPU] opted in after CPU infer failure.
  bool get _effectivePreferGpu =>
      _preferGpu ||
      (_allowEscalateCpuInferFailToGpu &&
          _androidEscalateLitertToGpu &&
          Platform.isAndroid &&
          !_multimodalRequiresGpu);

  bool _litertGenerateFailedMatchesCpuXnnpack786(PlatformException e) {
    if (e.code != 'generate_failed') return false;
    if (_forceCpuBackendBuildFlag) return false;
    if (!Platform.isAndroid || _multimodalRequiresGpu) return false;
    if (_preferGpu || _androidEscalateLitertToGpu) return false;
    if (_settings.lowRamProfile) return false;
    final m = e.message ?? '';
    return m.contains('786') ||
        m.contains('DYNAMIC_UPDATE_SLICE') ||
        m.contains('nativeSendMessage') ||
        m.contains('Failed to invoke the compiled model') ||
        m.contains('Failed to allocate tensors');
  }

  bool _shouldEscalateAndroidCpuLitertToGpu(PlatformException e) =>
      _allowEscalateCpuInferFailToGpu &&
      _litertGenerateFailedMatchesCpuXnnpack786(e);

  Future<void> _purgeInstallArtifacts() => purgeGemmaPluginInstallCandidates();

  Future<void> _installFromConfiguredSource() async {
    final variant = _settings.gemma4OnDeviceVariant;
    await _installFromHfService(
      GemmaHfModelDownloadService.forVariant(variant),
      onDeviceGemmaVariantLabel(variant),
    );
  }

  Future<void> _installFromHfService(
    GemmaHfModelDownloadService service,
    String label,
  ) async {
    final alreadyInstalled = await service.isPluginModelInstalled();
    _emit(
      'install',
      alreadyInstalled
          ? 'Using downloaded $label (${service.modelFilename})…'
          : 'Downloading $label (${service.modelFilename})…',
      alreadyInstalled ? 100 : 0,
    );
    try {
      if (!alreadyInstalled) {
        await ensureAndroidModelDownloadNotificationPermission();
      }
      final token = (await HuggingfaceAuthTokenStore.loadToken() ?? '').trim();
      if (!alreadyInstalled) {
        ModelDiagnostics.instance.log(
          area: 'engine',
          action: 'install_network_start',
          message: 'Installing $label from network',
          data: <String, Object?>{'url': service.modelUrl},
        );
        await service.downloadModel(
          token: token,
          onProgress: (p) => _emitProgress(p.round().clamp(0, 100)),
        );
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_network_ok',
        message: '$label install finished',
      );
    } on Object catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('space') ||
          msg.contains('storage') ||
          msg.contains('enospc')) {
        throw LlmResourceException(rawInstallErrorLabel(e));
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_network_failed',
        message: '$label download/install failed',
        data: <String, Object?>{'error': rawInstallErrorLabel(e)},
      );
      throw LlmUnavailableException(
        'Could not install $label: ${rawInstallErrorLabel(e)}',
      );
    }
  }

  Future<void> _nativeOpen({required bool preferGpu}) async {
    final path = await _service.getFilePath();
    await _nativeLoad(
      modelPath: path,
      maxTokens: _contextMaxTokens,
      preferGpu: preferGpu,
    );
  }

  Future<void> _openActiveModel() async {
    try {
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'open_attempt',
        message: 'Opening native model',
        data: <String, Object?>{
          'preferGpu': _effectivePreferGpu,
          'androidTextCpuDefault':
              Platform.isAndroid &&
              !_multimodalRequiresGpu &&
              !_effectivePreferGpu,
        },
      );
      // #region agent log
      agentDebugLog(
        location: 'flutter_gemma_llm_engine.dart:_openActiveModel',
        message: 'open path',
        hypothesisId: 'G',
        runId: 'post-fix',
        data: <String, Object?>{
          'preferGpu': _effectivePreferGpu,
          'basePreferGpu': _preferGpu,
          'androidEscalateLitertToGpu': _androidEscalateLitertToGpu,
          'isAndroid': Platform.isAndroid,
          'androidGpuOptIn': _androidGpuOptInForTextOnly,
        },
      );
      // #endregion
      if (_effectivePreferGpu) {
        await _nativeOpen(preferGpu: true).timeout(
          _kGpuModelOpenTimeout,
          onTimeout: () => throw TimeoutException(
            'GPU model initialization timed out (${_kGpuModelOpenTimeout.inSeconds}s). '
            'Falling back to CPU backend.',
          ),
        );
      } else {
        await _nativeOpen(preferGpu: false);
      }
      if (_effectivePreferGpu) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } on Object catch (e) {
      _lastOpenError = e;
      if (_preferGpu && !_multimodalRequiresGpu) {
        debugPrint(
          'FlutterGemmaLlmEngine: GPU backend failed, opening with CPU: $e',
        );
        ModelDiagnostics.instance.log(
          area: 'engine',
          action: 'gpu_fallback_to_cpu',
          message: 'GPU backend failed, falling back to CPU',
          data: <String, Object?>{"error": "$e"},
        );
        await _nativeOpen(preferGpu: false);
        return;
      }
      if (_preferGpu && _multimodalRequiresGpu) {
        ModelDiagnostics.instance.log(
          area: 'engine',
          action: 'open_failed',
          message: 'GPU open failed (multimodal model cannot fall back to CPU)',
          data: <String, Object?>{'error': '$e'},
        );
      } else {
        ModelDiagnostics.instance.log(
          area: 'engine',
          action: 'open_failed',
          message: 'Open active model failed',
          data: <String, Object?>{
            'preferGpu': _preferGpu,
            'error': '$e',
          },
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> ensureLoaded() async {
    if (_disposed) {
      throw StateError('FlutterGemmaLlmEngine disposed');
    }
    if (_loaded) return;

    // #region agent log
    agentDebugLog(
      location: 'flutter_gemma_llm_engine.dart:ensureLoaded',
      message: 'ensureLoaded scheduling body',
      hypothesisId: 'A',
      data: <String, Object?>{
        'inFlight': _ensureLoadedInFlight != null,
        'loaded': _loaded,
        'disposed': _disposed,
      },
    );
    // #endregion
    _ensureLoadedInFlight ??= _ensureLoadedBody();
    try {
      await _ensureLoadedInFlight!;
    } finally {
      _ensureLoadedInFlight = null;
    }
  }

  Future<void> _ensureLoadedBody() async {
    if (_disposed) {
      throw StateError('FlutterGemmaLlmEngine disposed');
    }
    if (_loaded) return;

    if (!shouldUseFlutterGemmaEngine) {
      throw LlmUnavailableException(
        'On-device Gemma runs on Android and iOS only.',
      );
    }

    final cached = await ModelCacheChecker.isCached(
      _settings.gemma4OnDeviceVariant,
    );
    if (cached) {
      _emit('open', 'Model found in storage — opening…', null);
    } else {
      _emit(
        'open',
        'Looking for on-device Gemma weights (GPU preferred: $_preferGpu)…',
        null,
      );
      await _installFromConfiguredSource();
    }

    if (shouldUseFlutterGemmaEngine && Platform.isAndroid && _effectivePreferGpu) {
      await SchedulerBinding.instance.endOfFrame;
    }

    try {
      await _openActiveModel();
      _emit('ready', 'Model opened — ready to generate.', 100);
      _finishLoaded();
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'ensure_loaded',
        message: 'Native model opened',
      );
      return;
    } on Object catch (e) {
      _lastOpenError = e;
      if (gemmaErrorLooksLikeGpuResourceExhaustion(e) && _preferGpu) {
        if (_multimodalRequiresGpu) {
          _emit('open', 'GPU load issue ($e) — will retry GPU shortly…', null);
        } else {
          _emit('open', 'GPU resource limit hit ($e) — forcing CPU backend…', null);
        }
      } else {
        _emit('open', 'First open failed: $e — retrying…', null);
      }
      debugPrint(
        'FlutterGemmaLlmEngine: open active model failed ($e); retrying once.',
      );
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final gpuExhaustion = _lastOpenError != null &&
          gemmaErrorLooksLikeGpuResourceExhaustion(_lastOpenError!);
      if (gpuExhaustion && _multimodalRequiresGpu) {
        _emit(
          'open',
          'GPU was busy (UI + model). Pausing briefly, then retrying GPU…',
          null,
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (gpuExhaustion && !_multimodalRequiresGpu) {
        await _nativeOpen(preferGpu: false);
      } else {
        await _openActiveModel();
      }
      _emit('ready', 'Model opened on second try.', 100);
      _finishLoaded();
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'ensure_loaded_retry_ok',
        message: 'Second open attempt succeeded',
      );
      return;
    } on Object catch (e) {
      _emit('recover', 'Still failing ($e). Clearing stale file and reinstalling…', null);
      debugPrint(
        'FlutterGemmaLlmEngine: second open failed ($e); purging and reinstalling.',
      );
    }

    await _purgeInstallArtifacts();
    await _installFromConfiguredSource();

    try {
      await _openActiveModel();
      _emit('ready', 'Model opened after reinstall.', 100);
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'ensure_loaded_after_install',
        message: 'Open succeeded after reinstall',
      );
    } on Object catch (e) {
      debugPrint(
        'FlutterGemmaLlmEngine: first open after install failed ($e), '
        'purging and retrying once.',
      );
      await _purgeInstallArtifacts();
      await _installFromConfiguredSource();
      try {
        await _openActiveModel();
        _emit('ready', 'Model opened after second reinstall.', 100);
        ModelDiagnostics.instance.log(
          area: 'engine',
          action: 'ensure_loaded_second_reinstall_ok',
          message: 'Open succeeded after second reinstall',
        );
      } on Object catch (e2) {
        if (gemmaErrorLooksLikeInvalidTaskArchive(e2)) {
          final hint =
              'Try re-downloading ${onDeviceGemmaVariantLabel(_settings.gemma4OnDeviceVariant)} '
              'from Settings → Choose on-device model, or free storage and retry.';
          throw LlmUnavailableException(
            'The model is not a valid Gemma archive (native loader could not open it '
            'as a zip). $hint '
            'Underlying error: ${rawInstallErrorLabel(e2)}',
          );
        }
        throw LlmUnavailableException(
          'Could not open Gemma model after reinstall: ${rawInstallErrorLabel(e2)}',
        );
      }
    }

    _finishLoaded();
  }

  /// Keeps the native prompt under [EngineConfig.maxNumTokens] (see NDJSON:
  /// `547 >= 512` when [promptChars] ~2256).
  String _truncatePromptForLiteRt(String prompt, int maxNewTokens) {
    final window = _contextMaxTokens;
    const overheadTokens = 48;
    final maxInputTokens = (window - maxNewTokens - overheadTokens).clamp(
      64,
      window - 32,
    );
    const charsPerToken = 3.5;
    final maxChars = (maxInputTokens * charsPerToken).floor();
    if (prompt.length <= maxChars) return prompt;
    final truncated =
        '${prompt.substring(0, maxChars)}\n…[truncated for on-device context]';
    // #region agent log
    agentDebugLog(
      location: 'flutter_gemma_llm_engine.dart:_truncatePromptForLiteRt',
      message: 'prompt truncated for native context',
      hypothesisId: 'H8',
      runId: 'post-fix',
      data: <String, Object?>{
        'window': window,
        'maxNew': maxNewTokens,
        'maxInputTokens': maxInputTokens,
        'beforeChars': prompt.length,
        'afterChars': truncated.length,
      },
    );
    // #endregion
    return truncated;
  }

  Map<String, Object?> _genArgs(LlmGenerateRequest request) {
    final maxNew = LlmLimits.clampMaxNewTokens(
      request.maxTokens ?? LlmLimits.defaultMaxNewTokens,
    );
    return <String, Object?>{
      'prompt': _truncatePromptForLiteRt(request.prompt.text, maxNew),
      'temperature': GemmaInferenceDefaults.temperature,
      'randomSeed': GemmaInferenceDefaults.randomSeed,
      'topK': GemmaInferenceDefaults.topK,
      'topP': GemmaInferenceDefaults.topP,
      'enableThinking': GemmaInferenceDefaults.enableThinking,
      'maxNewTokens': maxNew,
    };
  }

  @override
  Future<ModelBoundCompletion> generate(LlmGenerateRequest request) async {
    if (_disposed) throw StateError('FlutterGemmaLlmEngine disposed');
    if (!_loaded) await ensureLoaded();

    Future<ModelBoundCompletion> runInfer() async {
      var text = await NativeLlmPlatform.generate(_genArgs(request));
      text = _applyStopSequences(text, request.stopSequences);
      return ModelBoundCompletion(
        LlmOutputFilters.takeThroughFirstBalancedJson(text),
      );
    }

    Future<void> logAndResetAfterGenerateFailed(
      PlatformException e, {
      required String hypothesisId,
      required String message,
    }) async {
      _loaded = false;
      try {
        await NativeLlmPlatform.closeModel();
      } on Object {
        // MissingPlugin in tests; native may already be torn down.
      }
      // #region agent log
      agentDebugLog(
        location: 'flutter_gemma_llm_engine.dart:generate',
        message: message,
        hypothesisId: hypothesisId,
        runId: 'post-fix',
        data: <String, Object?>{
          'code': e.code,
          'messageLen': (e.message ?? '').length,
        },
      );
      // #endregion
    }

    try {
      return await runInfer();
    } on PlatformException catch (e) {
      if (e.code != 'generate_failed') {
        throw LlmResourceException('Inference failed: $e');
      }
      if (_litertGenerateFailedMatchesCpuXnnpack786(e) &&
          !_allowEscalateCpuInferFailToGpu) {
        // #region agent log
        agentDebugLog(
          location: 'flutter_gemma_llm_engine.dart:generate',
          message:
              'skipping automatic GPU reload after CPU LiteRT failure (opt-in off; '
              'GPU init crashed process in NDJSON 669518)',
          hypothesisId: 'H7',
          runId: 'post-fix',
          data: const <String, Object?>{},
        );
        // #endregion
      }
      if (_shouldEscalateAndroidCpuLitertToGpu(e)) {
        _androidEscalateLitertToGpu = true;
        await logAndResetAfterGenerateFailed(
          e,
          hypothesisId: 'H6',
          message: 'escalate LiteRT to GPU after CPU/XNNPack infer failure',
        );
        await ensureLoaded();
        // #region agent log
        agentDebugLog(
          location: 'flutter_gemma_llm_engine.dart:generate',
          message: 'post-escalation ensureLoaded complete',
          hypothesisId: 'H6b',
          runId: 'post-fix',
          data: <String, Object?>{'loaded': _loaded},
        );
        // #endregion
        // #region agent log
        agentDebugLog(
          location: 'flutter_gemma_llm_engine.dart:generate',
          message: 'GPU retry infer start',
          hypothesisId: 'H6c',
          runId: 'post-fix',
          data: const <String, Object?>{},
        );
        // #endregion
        try {
          return await runInfer();
        } on PlatformException catch (e2) {
          throw LlmResourceException('Inference failed: $e2');
        }
      }
      // Do not close/reload native weights here — reload does not fix XNNPack
      // 786 or oversize prompts and caused hundreds of loadModel cycles (NDJSON).
      throw LlmResourceException('Inference failed: $e');
    } on Object catch (e) {
      throw LlmResourceException('Inference failed: $e');
    }
  }

  String _applyStopSequences(String text, List<String> stops) {
    var earliest = text.length;
    for (final stop in stops) {
      if (stop.isEmpty) continue;
      final i = text.indexOf(stop);
      if (i >= 0 && i < earliest) earliest = i;
    }
    if (earliest < text.length) return text.substring(0, earliest);
    return text;
  }

  /// True when [e] is a native stream failure that matches the LiteRT-LM
  /// XNNPack / DYNAMIC_UPDATE_SLICE / executor 786 pattern on the **async**
  /// prefill path (`RunPrefillAsync`).
  ///
  /// These are recoverable by closing + reloading the engine and falling back
  /// to the synchronous [generate] path ([NativeLlmPlatform.generate]).
  static bool _streamFailedMatchesLiteRt(Object e) {
    if (e is! PlatformException) return false;
    if (e.code != 'stream_failed') return false;
    final m = (e.message ?? '').toLowerCase();
    return m.contains('failed to invoke') ||
        m.contains('failed to allocate') ||
        m.contains('dynamic_update_slice') ||
        m.contains('status code:') ||
        m.contains('litertlmjniexception') ||
        m.contains('litertlm') ||
        m.contains('litert');
  }

  @override
  Stream<String> generateChunkStream(LlmGenerateRequest request) {
    if (_disposed) {
      return Stream.error(StateError('FlutterGemmaLlmEngine disposed'));
    }

    final controller = StreamController<String>();
    unawaited(() async {
      try {
        if (!_loaded) await ensureLoaded();
        await for (final token in NativeLlmPlatform.generateStream(
          _genArgs(request),
        )) {
          if (token.isEmpty) continue;
          if (!controller.isClosed) controller.add(token);
        }
        await controller.close();
      } on PlatformException catch (e, st) {
        // Reset engine state so callers can invalidate + reload cleanly.
        // The Kotlin conversation is already closed in the finally block of
        // litertGenerateStream, but the Dart _loaded flag is still true.
        if (_streamFailedMatchesLiteRt(e)) {
          _loaded = false;
          unawaited(() async {
            try {
              await NativeLlmPlatform.closeModel();
            } on Object {
              // ignore — best-effort cleanup before caller reloads
            }
          }());
          // #region agent log
          agentDebugLog(
            location: 'flutter_gemma_llm_engine.dart:generateChunkStream',
            message: 'stream_failed matches LiteRT pattern — reset _loaded, '
                'closed native; caller should invalidate + retry sync',
            hypothesisId: 'H_stream_786',
            runId: 'stream-fix',
            data: <String, Object?>{
              'code': e.code,
              'messageLen': (e.message ?? '').length,
            },
          );
          // #endregion
        }
        if (!controller.isClosed) controller.addError(e, st);
        await controller.close();
      } on Object catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
        await controller.close();
      }
    }());
    return controller.stream;
  }

  @override
  void dispose() {
    // #region agent log
    agentDebugLog(
      location: 'flutter_gemma_llm_engine.dart:dispose',
      message: 'engine dispose',
      hypothesisId: 'A',
      data: <String, Object?>{'wasLoaded': _loaded},
    );
    // #endregion
    _disposed = true;
    _loaded = false;
    unawaited(() async {
      try {
        await NativeLlmPlatform.closeModel();
      } on Object catch (e) {
        debugPrint('FlutterGemmaLlmEngine.dispose: closeModel: $e');
      }
    }());
  }
}

/// True when this process should use the real on-device stack (mobile shells only).
bool get shouldUseFlutterGemmaEngine => computeShouldUseFlutterGemmaEngine(
  isWeb: kIsWeb,
  isAndroid: Platform.isAndroid,
  isIos: Platform.isIOS,
);

/// Test access to the native `generate` / `generateStream` argument map (Req. 8.2).
extension FlutterGemmaLlmEngineChannelArgsTest on FlutterGemmaLlmEngine {
  Map<String, Object?> channelArgsForTest(LlmGenerateRequest request) =>
      _genArgs(request);

  String applyStopSequencesForTest(String text, List<String> stops) =>
      _applyStopSequences(text, stops);
}
