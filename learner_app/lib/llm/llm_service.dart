import 'package:flutter/foundation.dart';

import '../state/settings_store.dart';
import 'flutter_gemma_llm_engine.dart';
import 'llm_engine.dart';
import 'llm_exceptions.dart';
import 'llm_generate_request.dart';
import 'llm_limits.dart';
import 'model_diagnostics.dart';
import 'streaming_llm_capability.dart';

/// App-wide access to on-device LLM (TASKS §6.4–6.8).
///
/// Uses [FlutterGemmaLlmEngine]: **Gemma 4 E2B** from bundled `.litertlm`
/// (`fromAsset`) or **E4B** from network (`fromNetwork`), per
/// [SettingsStore.gemma4OnDeviceVariant]. [ensureLoaded] opens the active model
/// or reinstalls. Call [configure] with [SettingsStore] before generation.
///
/// Removed: `ProcessLlmEngine` / `llama-cli` / GGUF / `native/build` paths.
class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  SettingsStore? _settings;
  LlmEngine? _engine;
  bool _disposed = false;
  void Function(int installPercent)? _onModelInstallProgress;
  void Function(String phase, String message, int? percent)? _onModelLifecycle;

  /// `true` after [ensureReady] finishes and the on-device weights are loaded
  /// ([engine.ensureLoaded] completed). Resets to `false` when
  /// [invalidateCachedEngine] runs. Use with [ValueListenableBuilder] or
  /// [Listenable.merge] so any page can react without calling the LLM again.
  final ValueNotifier<bool> onDeviceWeightsReady = ValueNotifier<bool>(false);

  /// Optional: [onModelInstallProgress] 0–100 during bytes transfer;
  /// [onModelLifecycle] verbose steps for UI (phase label + message + optional %).
  ///
  /// When either callback is non-null, the cached engine is **discarded** so the
  /// next load uses these hooks (e.g. home hub attaching a status log).
  void configure(
    SettingsStore settings, {
    void Function(int installPercent)? onModelInstallProgress,
    void Function(String phase, String message, int? percent)? onModelLifecycle,
  }) {
    _settings = settings;
    _onModelInstallProgress = onModelInstallProgress;
    _onModelLifecycle = onModelLifecycle;
    if (onModelInstallProgress != null || onModelLifecycle != null) {
      invalidateCachedEngine();
    }
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'configure',
      message: 'Configured LLM service',
      data: <String, Object?>{'lowRam': settings.lowRamProfile},
    );
  }

  /// Validates engine + on-disk model (reinstalls from bundled assets if needed).
  Future<void> ensureReady() async {
    _throwIfDisposed();
    final engine = _engine ??= _createEngine();
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'ensure_ready',
      message: 'Ensuring model is ready',
    );
    await engine.ensureLoaded().timeout(
      const Duration(seconds: 600),
      onTimeout: () => throw LlmResourceException(
        'Model preparation timed out. If this is the first launch, wait on '
        'power and try again; otherwise check storage and reinstall.',
      ),
    );
    onDeviceWeightsReady.value = true;
  }

  /// Same as [configure] with **only** [settings]: clears install/lifecycle
  /// hooks **without** disposing the cached engine. Call after the home hub has
  /// finished warming so other routes keep using the loaded weights until the
  /// next [configure] that passes progress callbacks (which triggers
  /// [invalidateCachedEngine]).
  void releaseInstallUiHooks(SettingsStore settings) {
    configure(settings);
  }

  /// Runs one completion using the active [LlmEngine].
  Future<ModelBoundCompletion> generate(LlmGenerateRequest request) async {
    _throwIfDisposed();
    final lowRam = _settings?.lowRamProfile ?? false;
    final ctx = LlmLimits.clampContext(
      request.contextSize ?? 0,
      lowRamProfile: lowRam,
    );
    final maxNew = LlmLimits.clampMaxNewTokens(
      request.maxTokens ?? LlmLimits.defaultMaxNewTokens,
    );
    final resolved = LlmGenerateRequest(
      prompt: request.prompt,
      maxTokens: maxNew,
      stopSequences: request.stopSequences,
      contextSize: ctx,
    );

    final engine = _engine ??= _createEngine();
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'generate',
      message: 'Run one-shot generation',
      data: <String, Object?>{'maxTokens': maxNew, 'context': ctx},
    );
    await engine.ensureLoaded();
    return engine
        .generate(resolved)
        .timeout(
          const Duration(seconds: 180),
          onTimeout: () => throw LlmResourceException(
            'Generation timed out. Try Low RAM mode in Settings or a shorter activity.',
          ),
        );
  }

  /// Streaming path for [spec.md](../../../spec.md) §7.3 when the active engine
  /// implements [StreamingLlmCapability]. Otherwise returns `null` — use [generate].
  Future<Stream<String>?> tryOpenGenerateStream(
    LlmGenerateRequest request,
  ) async {
    _throwIfDisposed();
    final lowRam = _settings?.lowRamProfile ?? false;
    final ctx = LlmLimits.clampContext(
      request.contextSize ?? 0,
      lowRamProfile: lowRam,
    );
    final maxNew = LlmLimits.clampMaxNewTokens(
      request.maxTokens ?? LlmLimits.defaultMaxNewTokens,
    );
    final resolved = LlmGenerateRequest(
      prompt: request.prompt,
      maxTokens: maxNew,
      stopSequences: request.stopSequences,
      contextSize: ctx,
    );

    final engine = _engine ??= _createEngine();
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'generate_stream_open',
      message: 'Open stream generation',
      data: <String, Object?>{'maxTokens': maxNew, 'context': ctx},
    );
    await engine.ensureLoaded();
    if (engine is StreamingLlmCapability) {
      return (engine as StreamingLlmCapability).generateChunkStream(resolved);
    }
    return null;
  }

  LlmEngine _createEngine() {
    final settings = _settings;
    if (settings == null) {
      throw StateError(
        'LlmService.configure(SettingsStore) must be called before using the LLM.',
      );
    }
    return FlutterGemmaLlmEngine(
      settings: settings,
      onInstallProgress: _onModelInstallProgress,
      onLifecycle: _onModelLifecycle,
    );
  }

  /// Call after profile knobs that affect context size / backend choice change.
  void invalidateCachedEngine() {
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'invalidate_cache',
      message: 'Invalidated engine cache',
    );
    _engine?.dispose();
    _engine = null;
    onDeviceWeightsReady.value = false;
  }

  void dispose() {
    _disposed = true;
    _engine?.dispose();
    _engine = null;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('LlmService disposed');
    }
  }
}
