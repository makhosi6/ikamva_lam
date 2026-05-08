import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../state/settings_store.dart';
import 'gemma4_ondevice_variant.dart';
import 'gemma_hf_model_download_service.dart';
import 'huggingface_auth_token_store.dart';
import 'gemma_inference_defaults.dart';
import 'gemma_model_config.dart';
import 'model_diagnostics.dart';
import 'llm_engine.dart';
import 'llm_exceptions.dart';
import 'llm_generate_request.dart';
import 'llm_output_filters.dart';
import 'model_prepare_config.dart';
import 'model_prepare_prefs.dart';
import 'streaming_llm_capability.dart';

/// iOS Metal / TFLite GPU delegate failed — the `.task` file is often fine; use
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

/// True when LiteRT failed to read the **artifact** as a zip (truncated / wrong file).
///
/// We intentionally **do not** match bare `GenAiInferenceError` /
/// `failedToInitializeEngine` — those also appear for GPU delegate failures on iOS.
bool gemmaErrorLooksLikeInvalidTaskArchive(Object error) {
  if (gemmaErrorLooksLikeGpuMetalDelegateFailure(error)) return false;
  final s = error.toString().toLowerCase();
  return s.contains('zip archive') ||
      s.contains('unable to open zip') ||
      (s.contains('unable to open') && s.contains('zip'));
}

/// True when the plugin has an active inference spec **and** reports its files
/// on disk. [FlutterGemma.hasActiveModel] alone can be true after the weights
/// were removed (stale registration).
Future<bool> flutterGemmaActiveInferenceInstalled() async {
  if (!FlutterGemma.hasActiveModel()) return false;
  final mgr = FlutterGemmaPlugin.instance.modelManager;
  final spec = mgr.activeInferenceModel;
  if (spec == null) return false;
  try {
    return await mgr.isModelInstalled(spec);
  } on Object {
    return false;
  }
}

/// Unregisters installed model ids so a bad copy is not reused. Includes ids
/// derived from HF URLs and legacy artifact names from older app versions.
Future<void> purgeGemmaPluginInstallCandidates() async {
  final ids = <String>{
    ...GemmaModelConfig.pluginUninstallCandidateIdsFor(
      GemmaModelConfig.gemma4E2bLitertlmUrl,
    ),
    ...GemmaModelConfig.pluginUninstallCandidateIdsFor(
      GemmaModelConfig.gemma4E4bLitertlmUrl,
    ),
    'ikamva_ondevice_model',
    'bundled_gemma.task',
  };
  for (final id in ids) {
    if (id.isEmpty) continue;
    try {
      await FlutterGemma.uninstallModel(id);
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'purge_uninstall',
        message: 'Uninstalled model candidate',
        data: <String, Object?>{'id': id},
      );
      debugPrint('purgeGemmaPluginInstallCandidates: uninstalled $id');
    } on Object {
      // Not registered under this id — ignore.
    }
  }
}

/// Returns whether an installed Gemma model can be opened with the same
/// backend / context limits as [FlutterGemmaLlmEngine] (mobile only).
///
/// Used on cold start so a stale `ModelPreparePrefs` flag cannot skip the
/// hub warm-up / `ensureReady` after uninstall or corruption.
Future<bool> probeFlutterGemmaActiveModelReady(SettingsStore settings) async {
  if (!shouldUseFlutterGemmaEngine) return true;
  if (!await flutterGemmaActiveInferenceInstalled()) {
    ModelDiagnostics.instance.log(
      area: 'probe',
      action: 'skip_no_install',
      message:
          'No lesson-helper model registered yet (finish Download on the setup '
          'screen and Continue, or Settings → Warm up). Probe skipped.',
    );
    return false;
  }
  Future<bool> probe(PreferredBackend backend) async {
    try {
      ModelDiagnostics.instance.log(
        area: 'probe',
        action: 'open_attempt',
        message: 'Trying to open active model',
        data: <String, Object?>{'backend': backend.name},
      );
      final model = await FlutterGemma.getActiveModel(
        maxTokens: ModelPrepareConfig.contextMaxTokensFor(settings.lowRamProfile),
        preferredBackend: backend,
        supportImage: GemmaModelConfig.activeModelSupportImage,
        supportAudio: GemmaModelConfig.activeModelSupportAudio,
        maxNumImages: GemmaModelConfig.activeModelMaxNumImages,
      );
      try {
        await model.close();
      } on Object catch (e) {
        debugPrint(
          'probeFlutterGemmaActiveModelReady: model.close() ignored: $e',
        );
      }
      return true;
    } on Object catch (e) {
      ModelDiagnostics.instance.log(
        area: 'probe',
        action: 'open_failed',
        message: 'Failed to open active model',
        data: <String, Object?>{'backend': backend.name, 'error': '$e'},
      );
      debugPrint('probeFlutterGemmaActiveModelReady ($backend): $e');
      return false;
    }
  }

  final primary = settings.lowRamProfile
      ? PreferredBackend.cpu
      : PreferredBackend.gpu;
  if (await probe(primary)) return true;
  if (primary == PreferredBackend.gpu && await probe(PreferredBackend.cpu)) {
    return true;
  }
  return false;
}

/// On-device inference via [flutter_gemma] — Gemma 4 **E2B/E4B** from Hugging Face
/// (`fromNetwork`). [ensureLoaded] re-opens the active model or re-downloads if needed.
class FlutterGemmaLlmEngine implements LlmEngine, StreamingLlmCapability {
  FlutterGemmaLlmEngine({
    required SettingsStore settings,
    void Function(int installPercent)? onInstallProgress,
    void Function(String phase, String message, int? percent)? onLifecycle,
  }) : _settings = settings,
       _onInstallProgress = onInstallProgress,
       _onLifecycle = onLifecycle;

  final SettingsStore _settings;
  final void Function(int)? _onInstallProgress;
  final void Function(String phase, String message, int? percent)? _onLifecycle;

  void _emit(String phase, String message, [int? percent]) {
    _onLifecycle?.call(phase, message, percent);
  }

  void _emitProgress(int p) {
    _onInstallProgress?.call(p);
    _onLifecycle?.call('progress', 'Transfer: $p%', p.clamp(0, 100));
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

  InferenceModel? _model;
  bool _loaded = false;
  bool _disposed = false;

  /// Single-flight guard: concurrent [ensureLoaded] calls (hub + setup + sentiment)
  /// must not each open the LiteRT model — native GPU init is huge and parallel
  /// opens OOM-kill the process (see `trimMemory` / "Lost connection to device").
  Future<void>? _ensureLoadedInFlight;

  int get _contextMaxTokens =>
      ModelPrepareConfig.contextMaxTokensFor(_settings.lowRamProfile);

  PreferredBackend get _preferredBackend =>
      _settings.lowRamProfile ? PreferredBackend.cpu : PreferredBackend.gpu;

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

  /// Example [ModelDownloadService.downloadModel] path (`fromNetwork` + progress).
  Future<void> _installFromHfService(
    GemmaHfModelDownloadService service,
    String label,
  ) async {
    _emit('install', 'Downloading $label (${service.modelFilename})…', 0);
    try {
      final raw = await HuggingfaceAuthTokenStore.loadToken() ?? '';
      final token = service.needsAuth ? raw : '';
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
        throw LlmResourceException(
          'Not enough storage to download $label. Free space and try again.',
        );
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_network_failed',
        message: '$label download/install failed',
        data: <String, Object?>{'error': '$e'},
      );
      throw LlmUnavailableException('Could not install $label: $e');
    }
  }

  Future<InferenceModel> _openActiveModel() async {
    try {
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'open_attempt',
        message: 'Opening active model',
        data: <String, Object?>{'backend': _preferredBackend.name},
      );
      return await FlutterGemma.getActiveModel(
        maxTokens: _contextMaxTokens,
        preferredBackend: _preferredBackend,
        supportImage: GemmaModelConfig.activeModelSupportImage,
        supportAudio: GemmaModelConfig.activeModelSupportAudio,
        maxNumImages: GemmaModelConfig.activeModelMaxNumImages,
      );
    } on Object catch (e) {
      // Match hub/settings warm-up: on iOS, any GPU open failure can be a
      // LiteRT / TFLite graph issue (Simulator is especially common), not only
      // delegate strings we classify as Metal.
      if (_preferredBackend == PreferredBackend.gpu && Platform.isIOS) {
        debugPrint(
          'FlutterGemmaLlmEngine: GPU backend failed, opening with CPU: $e',
        );
        return FlutterGemma.getActiveModel(
          maxTokens: _contextMaxTokens,
          preferredBackend: PreferredBackend.cpu,
          supportImage: GemmaModelConfig.activeModelSupportImage,
          supportAudio: GemmaModelConfig.activeModelSupportAudio,
          maxNumImages: GemmaModelConfig.activeModelMaxNumImages,
        );
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'open_failed',
        message: 'Open active model failed',
        data: <String, Object?>{
          'backend': _preferredBackend.name,
          'error': '$e',
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> ensureLoaded() async {
    if (_disposed) {
      throw StateError('FlutterGemmaLlmEngine disposed');
    }
    if (_loaded && _model != null) return;

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
    if (_loaded && _model != null) return;

    if (!shouldUseFlutterGemmaEngine) {
      throw LlmUnavailableException(
        'On-device Gemma runs on Android and iOS only.',
      );
    }

    _emit(
      'open',
      'Looking for an existing on-device Gemma install (backend: '
      '${_preferredBackend.name})…',
      null,
    );
    // Example `ChatScreen`: always `installModel`…`install()` first (idempotent),
    // then `getActiveModel`. Re-register when there is no active spec **or**
    // the spec is stale (active pointer but files missing — avoids
    // "no longer installed" before we open).
    //
    // Removing the pre-check matches `_example_bak` behavior exactly.
    await _installFromConfiguredSource();

    try {
      _model = await _openActiveModel();
      _emit('ready', 'Model opened — ready to generate.', 100);
      _finishLoaded();
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'ensure_loaded',
        message: 'Active model opened without reinstall',
      );
      return;
    } on Object catch (e) {
      _model = null;
      _emit('open', 'First open failed: $e — retrying…', null);
      debugPrint(
        'FlutterGemmaLlmEngine: open active model failed ($e); retrying once.',
      );
    }

    // Brief delay: another screen may have just verified the install with a
    // separate handle; native teardown can lag one frame.
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _model = await _openActiveModel();
      _emit('ready', 'Model opened on second try.', 100);
      _finishLoaded();
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'ensure_loaded_retry_ok',
        message: 'Second open attempt succeeded',
      );
      return;
    } on Object catch (e) {
      _model = null;
      _emit('recover', 'Still failing ($e). Clearing stale install and reinstalling…', null);
      debugPrint(
        'FlutterGemmaLlmEngine: second open failed ($e); purging and reinstalling.',
      );
    }

    await _purgeInstallArtifacts();
    await _installFromConfiguredSource();

    try {
      _model = await _openActiveModel();
      _emit('ready', 'Model opened after reinstall.', 100);
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'ensure_loaded_after_install',
        message: 'Open succeeded after reinstall',
      );
    } on Object catch (e) {
      _model = null;
      debugPrint(
        'FlutterGemmaLlmEngine: first open after install failed ($e), '
        'purging and retrying once.',
      );
      await _purgeInstallArtifacts();
      await _installFromConfiguredSource();
      try {
        _model = await _openActiveModel();
        _emit('ready', 'Model opened after second reinstall.', 100);
        ModelDiagnostics.instance.log(
          area: 'engine',
          action: 'ensure_loaded_second_reinstall_ok',
          message: 'Open succeeded after second reinstall',
        );
      } on Object catch (e2) {
        _model = null;
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
            'The model is not a valid Gemma archive (LiteRT could not open it '
            'as a zip). $hint '
            'Underlying error: $e2',
          );
        }
        throw LlmUnavailableException(
          'Could not open Gemma model after reinstall: $e2',
        );
      }
    }

    _finishLoaded();
  }

  @override
  Future<ModelBoundCompletion> generate(LlmGenerateRequest request) async {
    if (_disposed) throw StateError('FlutterGemmaLlmEngine disposed');
    if (!_loaded) await ensureLoaded();
    final model = _model!;

    // Gemma 4 / LiteRT-LM: sampling defaults recommended in flutter_gemma docs
    // (thinking off; structured JSON prompts still benefit from topK/topP).
    final session = await model.createSession(
      temperature: GemmaInferenceDefaults.temperature,
      randomSeed: GemmaInferenceDefaults.randomSeed,
      topK: GemmaInferenceDefaults.topK,
      topP: GemmaInferenceDefaults.topP,
      enableThinking: GemmaInferenceDefaults.enableThinking,
    );
    try {
      await session.addQueryChunk(
        Message.text(text: request.prompt.text, isUser: true),
      );
      var text = await session.getResponse();
      text = _applyStopSequences(text, request.stopSequences);
      return ModelBoundCompletion(
        LlmOutputFilters.takeThroughFirstBalancedJson(text),
      );
    } on Object catch (e) {
      throw LlmResourceException('Inference failed: $e');
    } finally {
      await session.close();
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
        final model = _model!;
        final session = await model.createSession(
          temperature: GemmaInferenceDefaults.temperature,
          randomSeed: GemmaInferenceDefaults.randomSeed,
          topK: GemmaInferenceDefaults.topK,
          topP: GemmaInferenceDefaults.topP,
          enableThinking: GemmaInferenceDefaults.enableThinking,
        );
        try {
          await session.addQueryChunk(
            Message.text(text: request.prompt.text, isUser: true),
          );
          await for (final token in session.getResponseAsync()) {
            if (!controller.isClosed) controller.add(token);
          }
        } finally {
          await session.close();
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
    final m = _model;
    _model = null;
    if (m != null) {
      unawaited(m.close());
    }
  }
}

/// True when this process should use the real Gemma plugin (mobile shells only).
bool get shouldUseFlutterGemmaEngine {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}
