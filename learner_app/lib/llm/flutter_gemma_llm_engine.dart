import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../state/settings_store.dart';
import 'device_model_storage.dart';
import 'gemma4_model_download_service.dart';
import 'gemma4_ondevice_variant.dart';
import 'gemma_inference_defaults.dart';
import 'gemma_model_config.dart';
import 'model_asset_manifest.dart';
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

/// Unregisters installed model ids so a bad copy is not reused. Includes ids
/// derived from the bundled asset and legacy artifact names from older app versions.
Future<void> purgeGemmaPluginInstallCandidates() async {
  final ids = <String>{
    ...GemmaModelConfig.pluginUninstallCandidateIdsFor(
      ModelPrepareConfig.bundledModelAssetPath,
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

/// On-device inference via [flutter_gemma] — **bundled** `.litertlm` only
/// (`installModel`…`fromAsset`). [ensureLoaded] re-opens the active model or
/// re-installs from assets if open fails.
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

  int get _contextMaxTokens =>
      ModelPrepareConfig.contextMaxTokensFor(_settings.lowRamProfile);

  PreferredBackend get _preferredBackend =>
      _settings.lowRamProfile ? PreferredBackend.cpu : PreferredBackend.gpu;

  Future<void> _purgeInstallArtifacts() => purgeGemmaPluginInstallCandidates();

  Future<void> _installFromBundledAsset() async {
    final assetPath = ModelPrepareConfig.bundledModelAssetPath;
    _emit('install', 'Registering model from app bundle ($assetPath)…', 0);
    try {
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_bundled_start',
        message: 'Registering model from Flutter asset',
        data: <String, Object?>{'asset': assetPath},
      );
      await installBundledInferenceWeightsFromFlutterAsset(
        assetPath: assetPath,
        onProgress: _emitProgress,
      );
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_bundled_ok',
        message: 'Bundled model install finished',
      );
    } on Object catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('space') ||
          msg.contains('storage') ||
          msg.contains('enospc')) {
        throw LlmResourceException(
          'Not enough storage to install the on-device model from the app '
          'bundle. Free space and try again.',
        );
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_bundled_failed',
        message: 'Bundled model install failed',
        data: <String, Object?>{'error': '$e'},
      );
      throw LlmUnavailableException(
        'Could not install bundled Gemma model: $e',
      );
    }
  }

  Future<void> _installFromConfiguredSource() async {
    switch (_settings.gemma4OnDeviceVariant) {
      case Gemma4OnDeviceVariant.e2bBundled:
        final bundledPath = ModelPrepareConfig.bundledModelAssetPath;
        final hasBundle = await modelAssetListedInBundle(bundledPath);
        if (hasBundle) {
          await _installFromBundledAsset();
          return;
        }
        throw LlmUnavailableException(
          'Gemma weights are missing: `$bundledPath` is not in the asset manifest. '
          'Add `assets/models/gemma-4-E2B-it.litertlm` to `pubspec.yaml` and rebuild.',
        );
      case Gemma4OnDeviceVariant.e4bNetwork:
        await _installE4bFromNetwork();
    }
  }

  Future<void> _installE4bFromNetwork() async {
    _emit(
      'install',
      'Downloading Gemma 4 E4B (${GemmaModelConfig.gemma4E4bLitertlmFilename})…',
      0,
    );
    try {
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_network_start',
        message: 'Installing Gemma 4 E4B from network',
        data: <String, Object?>{
          'url': GemmaModelConfig.gemma4E4bLitertlmUrl,
        },
      );
      await Gemma4ModelDownloadService.downloadE4b(
        (p) => _emitProgress(p.round().clamp(0, 100)),
      );
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_network_ok',
        message: 'Gemma 4 E4B install finished',
      );
    } on Object catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('space') ||
          msg.contains('storage') ||
          msg.contains('enospc')) {
        throw LlmResourceException(
          'Not enough storage to download Gemma 4 E4B. Free space and try again.',
        );
      }
      ModelDiagnostics.instance.log(
        area: 'engine',
        action: 'install_network_failed',
        message: 'E4B download/install failed',
        data: <String, Object?>{'error': '$e'},
      );
      throw LlmUnavailableException('Could not install Gemma 4 E4B: $e');
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

    if (!shouldUseFlutterGemmaEngine) {
      throw LlmUnavailableException(
        'On-device Gemma runs on Android and iOS only.',
      );
    }

    if (_settings.gemma4OnDeviceVariant == Gemma4OnDeviceVariant.e2bBundled) {
      final listed = await modelAssetListedInBundle(
        ModelPrepareConfig.bundledModelAssetPath,
      );
      if (!listed) {
        throw LlmUnavailableException(
          'Bundled Gemma file is absent from the asset manifest. '
          'Place `gemma-4-E2B-it.litertlm` under assets/models/, ensure '
          '`${ModelPrepareConfig.bundledModelAssetPath}` is listed in '
          '`pubspec.yaml`, and rebuild — or open Settings → Choose on-device '
          'Gemma 4 model → Gemma 4 E4B (download).',
        );
      }
    }

    _emit(
      'open',
      'Looking for an existing on-device Gemma install (backend: '
      '${_preferredBackend.name})…',
      null,
    );
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
            Gemma4OnDeviceVariant.e2bBundled =>
              'Verify `${ModelPrepareConfig.bundledModelAssetPath}` in '
                  '`pubspec.yaml` is complete and is the native `.litertlm` artifact.',
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
