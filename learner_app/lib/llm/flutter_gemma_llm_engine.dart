import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
import 'llm_output_filters.dart';
import 'model_diagnostics.dart';
import 'model_prepare_config.dart';
import 'model_prepare_prefs.dart';
import 'native_llm_platform.dart';
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

GemmaHfModelDownloadService _hfServiceForVariant(Gemma4OnDeviceVariant v) {
  switch (v) {
    case Gemma4OnDeviceVariant.e2bHuggingFace:
      return GemmaHfModelDownloadService.e2b();
    case Gemma4OnDeviceVariant.e4bNetwork:
      return GemmaHfModelDownloadService.e4b();
  }
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
  Gemma4OnDeviceVariant variant,
) async {
  return _hfServiceForVariant(variant).isPluginModelInstalled();
}

/// Deletes known weight filenames under app documents and legacy plugin ids
/// (as filenames) so a bad copy is not reused.
Future<void> purgeGemmaPluginInstallCandidates() async {
  final base = await _documentsModelBaseDir();
  final ids = <String>{
    ...GemmaModelConfig.pluginUninstallCandidateIdsFor(
      GemmaModelConfig.gemma4E2bLitertlmUrl,
    ),
    ...GemmaModelConfig.pluginUninstallCandidateIdsFor(
      GemmaModelConfig.gemma4E4bLitertlmUrl,
    ),
    GemmaModelConfig.gemma4E2bLitertlmFilename,
    GemmaModelConfig.gemma4E4bLitertlmFilename,
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
  await NativeLlmPlatform.loadModel(<String, Object?>{
    'modelPath': modelPath,
    'maxTokens': maxTokens,
    'preferGpu': preferGpu,
    'supportImage': GemmaModelConfig.activeModelSupportImage,
    'supportAudio': GemmaModelConfig.activeModelSupportAudio,
    'maxNumImages': GemmaModelConfig.activeModelMaxNumImages,
  });
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
      : (!FlutterGemmaLlmEngine._forceCpuBackendBuildFlag &&
          !settings.lowRamProfile);
  if (await probe(primaryGpu)) return true;
  if (!multimodal && primaryGpu && await probe(false)) {
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
    return !_settings.lowRamProfile;
  }

  Future<void> _purgeInstallArtifacts() => purgeGemmaPluginInstallCandidates();

  Future<void> _installFromConfiguredSource() async {
    switch (_settings.gemma4OnDeviceVariant) {
      case Gemma4OnDeviceVariant.e2bHuggingFace:
        await _installFromHfService(
          GemmaHfModelDownloadService.e2b(),
          'Gemma 4 E2B',
        );
        return;
      case Gemma4OnDeviceVariant.e4bNetwork:
        await _installFromHfService(
          GemmaHfModelDownloadService.e4b(),
          'Gemma 4 E4B',
        );
        return;
    }
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
        data: <String, Object?>{'preferGpu': _preferGpu},
      );
      if (_preferGpu) {
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
      if (_preferGpu) {
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

    _emit(
      'open',
      'Looking for on-device Gemma weights (GPU preferred: $_preferGpu)…',
      null,
    );
    await _installFromConfiguredSource();

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
          final hint = switch (_settings.gemma4OnDeviceVariant) {
            Gemma4OnDeviceVariant.e2bHuggingFace =>
              'Try re-downloading Gemma 4 E2B from Hugging Face in Settings → '
                  'Choose on-device Gemma 4 model, or free storage and retry.',
            Gemma4OnDeviceVariant.e4bNetwork =>
              'Try choosing the on-device model again and re-download Gemma 4 E4B, '
                  'or free storage and retry.',
          };
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

  Map<String, Object?> _genArgs(LlmGenerateRequest request) {
    return <String, Object?>{
      'prompt': request.prompt.text,
      'temperature': GemmaInferenceDefaults.temperature,
      'randomSeed': GemmaInferenceDefaults.randomSeed,
      'topK': GemmaInferenceDefaults.topK,
      'topP': GemmaInferenceDefaults.topP,
      'enableThinking': GemmaInferenceDefaults.enableThinking,
      'maxNewTokens': request.maxTokens,
    };
  }

  @override
  Future<ModelBoundCompletion> generate(LlmGenerateRequest request) async {
    if (_disposed) throw StateError('FlutterGemmaLlmEngine disposed');
    if (!_loaded) await ensureLoaded();

    try {
      var text = await NativeLlmPlatform.generate(_genArgs(request));
      text = _applyStopSequences(text, request.stopSequences);
      return ModelBoundCompletion(
        LlmOutputFilters.takeThroughFirstBalancedJson(text),
      );
    } on Object catch (e) {
      throw LlmResourceException('Inference failed: $e');
    }
  }

  String _applyStopSequences(String text, List<String> stops) {
    var out = text;
    for (final stop in stops) {
      if (stop.isEmpty) continue;
      final i = out.indexOf(stop);
      if (i >= 0) out = out.substring(0, i);
    }
    return out;
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
      } on Object catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
        await controller.close();
      }
    }());
    return controller.stream;
  }

  @override
  void dispose() {
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
bool get shouldUseFlutterGemmaEngine {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}
