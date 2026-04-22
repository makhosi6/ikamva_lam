import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../state/settings_store.dart';
import 'gemma_model_config.dart';
import 'llm_engine.dart';
import 'llm_exceptions.dart';
import 'llm_generate_request.dart';
import 'llm_output_filters.dart';
import 'model_prepare_config.dart';
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
/// derived from [ModelPrepareConfig.networkUrl] and legacy bundled artifact
/// names from older app versions.
Future<void> purgeGemmaPluginInstallCandidates() async {
  final url = ModelPrepareConfig.networkUrl;
  final ids = <String>{
    ...GemmaModelConfig.pluginUninstallCandidateIdsFor(url),
    'bundled_gemma.task',
  };
  for (final id in ids) {
    if (id.isEmpty) continue;
    try {
      await FlutterGemma.uninstallModel(id);
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
/// prepare screen after uninstall or corruption.
Future<bool> probeFlutterGemmaActiveModelReady(SettingsStore settings) async {
  if (!shouldUseFlutterGemmaEngine) return true;
  if (!ModelPrepareConfig.hasNetworkModelUrl) return false;
  if (GemmaModelConfig.mobileModelUrlBlockedReason(ModelPrepareConfig.networkUrl) !=
      null) {
    return false;
  }
  Future<bool> probe(PreferredBackend backend) async {
    try {
      final model = await FlutterGemma.getActiveModel(
        maxTokens: settings.lowRamProfile ? 512 : 1024,
        preferredBackend: backend,
      );
      try {
        await model.close();
      } on Object catch (e) {
        debugPrint('probeFlutterGemmaActiveModelReady: model.close() ignored: $e');
      }
      return true;
    } on Object catch (e) {
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

/// On-device inference via [flutter_gemma]. Models are **downloaded once** via
/// HTTP ([ModelPrepareConfig.networkUrl]) and kept in local plugin storage;
/// [ensureLoaded] re-opens the active model or re-downloads if open fails.
class FlutterGemmaLlmEngine implements LlmEngine, StreamingLlmCapability {
  FlutterGemmaLlmEngine({
    required SettingsStore settings,
    void Function(int installPercent)? onInstallProgress,
  })  : _settings = settings,
        _onInstallProgress = onInstallProgress;

  final SettingsStore _settings;
  final void Function(int)? _onInstallProgress;

  InferenceModel? _model;
  bool _loaded = false;
  bool _disposed = false;

  int get _contextMaxTokens =>
      _settings.lowRamProfile ? 512 : 1024;

  PreferredBackend get _preferredBackend =>
      _settings.lowRamProfile ? PreferredBackend.cpu : PreferredBackend.gpu;

  Future<void> _purgeInstallArtifacts() => purgeGemmaPluginInstallCandidates();

  Future<void> _installFromNetwork() async {
    final url = ModelPrepareConfig.networkUrl;
    final blocked = GemmaModelConfig.mobileModelUrlBlockedReason(url);
    if (blocked != null) {
      throw LlmUnavailableException(blocked);
    }
    if (url.isEmpty) {
      throw LlmUnavailableException(
        'No model download URL. Set compile-time '
        '`IKAMVA_MODEL_DOWNLOAD_URL` to an HTTPS link for a valid Gemma '
        '`.task` file (see assets/models/OBTAINING_MODELS.txt).',
      );
    }

    var builder = FlutterGemma.installModel(
      modelType: GemmaModelConfig.modelType,
      fileType: ModelPrepareConfig.fileTypeForInstallSource(url),
    ).fromNetwork(
      url,
      token: ModelPrepareConfig.hfToken.isEmpty
          ? null
          : ModelPrepareConfig.hfToken,
    );

    if (_onInstallProgress != null) {
      builder = builder.withProgress(_onInstallProgress);
    }

    try {
      await builder.install();
    } on Object catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('space') ||
          msg.contains('storage') ||
          msg.contains('enospc')) {
        throw LlmResourceException(
          'Not enough storage to download the on-device model. '
          'Free space and try again.',
        );
      }
      throw LlmUnavailableException('Could not download Gemma model: $e');
    }
  }

  Future<InferenceModel> _openActiveModel() async {
    try {
      return await FlutterGemma.getActiveModel(
        maxTokens: _contextMaxTokens,
        preferredBackend: _preferredBackend,
      );
    } on Object catch (e) {
      if (_preferredBackend == PreferredBackend.gpu &&
          gemmaErrorLooksLikeGpuMetalDelegateFailure(e)) {
        debugPrint(
          'FlutterGemmaLlmEngine: GPU backend failed, opening with CPU: $e',
        );
        return FlutterGemma.getActiveModel(
          maxTokens: _contextMaxTokens,
          preferredBackend: PreferredBackend.cpu,
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
    if (_loaded && _model != null) return;

    if (!ModelPrepareConfig.hasNetworkModelUrl) {
      throw LlmUnavailableException(
        'Missing `IKAMVA_MODEL_DOWNLOAD_URL`. The app does not ship model '
        'weights; add a compile-time HTTPS URL to your `.env` / '
        '`--dart-define-from-file` (see assets/models/OBTAINING_MODELS.txt).',
      );
    }

    final blocked = GemmaModelConfig.mobileModelUrlBlockedReason(
      ModelPrepareConfig.networkUrl,
    );
    if (blocked != null) {
      throw LlmUnavailableException(blocked);
    }

    try {
      _model = await _openActiveModel();
      _loaded = true;
      return;
    } on Object catch (e) {
      _model = null;
      debugPrint(
        'FlutterGemmaLlmEngine: open active model failed ($e); retrying once.',
      );
    }

    // Brief delay: another screen may have just verified the install with a
    // separate handle; native teardown can lag one frame.
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _model = await _openActiveModel();
      _loaded = true;
      return;
    } on Object catch (e) {
      _model = null;
      debugPrint(
        'FlutterGemmaLlmEngine: second open failed ($e); purging and re-downloading.',
      );
    }

    await _purgeInstallArtifacts();
    await _installFromNetwork();

    try {
      _model = await _openActiveModel();
    } on Object catch (e) {
      _model = null;
      debugPrint(
        'FlutterGemmaLlmEngine: first open after install failed ($e), '
        'purging and retrying once.',
      );
      await _purgeInstallArtifacts();
      await _installFromNetwork();
      try {
        _model = await _openActiveModel();
      } on Object catch (e2) {
        _model = null;
        if (gemmaErrorLooksLikeInvalidTaskArchive(e2)) {
          throw LlmUnavailableException(
            'The downloaded model is not a valid Gemma archive (LiteRT could '
            'not open it as a zip). Check `IKAMVA_MODEL_DOWNLOAD_URL` points '
            'to a complete `.task` file and `IKAMVA_HF_TOKEN` if the repo is '
            'gated. Underlying error: $e2',
          );
        }
        throw LlmUnavailableException(
          'Could not open Gemma model after download: $e2',
        );
      }
    }

    _loaded = true;
  }

  @override
  Future<ModelBoundCompletion> generate(LlmGenerateRequest request) async {
    if (_disposed) throw StateError('FlutterGemmaLlmEngine disposed');
    if (!_loaded) await ensureLoaded();
    final model = _model!;

    final session = await model.createSession();
    try {
      await session.addQueryChunk(
        Message(text: request.prompt.text, isUser: true),
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
        final session = await model.createSession();
        try {
          await session.addQueryChunk(
            Message(text: request.prompt.text, isUser: true),
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
