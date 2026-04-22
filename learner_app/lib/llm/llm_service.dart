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
/// Always uses [FlutterGemmaLlmEngine]: HTTP fetch into a **fixed cache file**
/// (`ModelLocalCache`) then **`FlutterGemma.installModel`…`fromFile`**; weights
/// are **not** shipped in the APK.
/// [ensureLoaded] re-opens the saved model or re-downloads if it is missing
/// or corrupt. Call [configure] with [SettingsStore] before generation.
///
/// Removed: `ProcessLlmEngine` / `llama-cli` / GGUF / `native/build` paths.
class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  SettingsStore? _settings;
  LlmEngine? _engine;
  bool _disposed = false;
  void Function(int installPercent)? _onModelInstallProgress;

  /// Optional: receive 0–100 progress while downloading/installing the model.
  Future<void> configure(
    SettingsStore settings, {
    void Function(int installPercent)? onModelInstallProgress,
  }) async {
    _settings = settings;
    _onModelInstallProgress = onModelInstallProgress;
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'configure',
      message: 'Configured LLM service',
      data: <String, Object?>{'lowRam': settings.lowRamProfile},
    );
  }

  /// Validates engine + on-disk model (re-downloads via HTTP if needed).
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
