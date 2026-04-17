import 'dart:io';

import '../state/settings_store.dart';
import 'llm_engine.dart';
import 'llm_generate_request.dart';
import 'llm_limits.dart';
import 'process_llm_engine.dart';
import 'stub_llm_engine.dart';

/// App-wide access to on-device LLM (TASKS §6.4–6.8).
class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  SettingsStore? _settings;
  LlmEngine? _engine;
  bool _disposed = false;

  Future<void> configure(SettingsStore settings) async {
    _settings = settings;
  }

  /// Validates engine + model paths (lazy unless called).
  Future<void> ensureReady() async {
    _throwIfDisposed();
    final engine = _engine ??= _createEngine();
    await engine.ensureLoaded();
  }

  /// Runs one completion using the active [LlmEngine] (process engine already
  /// uses a background isolate internally — TASKS §6.7).
  Future<String> generate(LlmGenerateRequest request) async {
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
    await engine.ensureLoaded();
    return engine.generate(resolved);
  }

  LlmEngine _createEngine() {
    if (Platform.environment['IKAMVA_USE_STUB_LLM'] == '1') {
      return StubLlmEngine();
    }
    final cli = _resolveCliPath();
    final model =
        Platform.environment['IKAMVA_GGUF'] ??
        const String.fromEnvironment('IKAMVA_GGUF', defaultValue: '');
    if (cli != null &&
        model.isNotEmpty &&
        File(cli).existsSync() &&
        File(model).existsSync()) {
      return ProcessLlmEngine(cliPath: cli, modelPath: model);
    }
    return StubLlmEngine();
  }

  String? _resolveCliPath() {
    final env = Platform.environment['IKAMVA_LLAMA_CLI'];
    if (env != null && env.isNotEmpty) return env;
    const fromDefine = String.fromEnvironment('IKAMVA_LLAMA_CLI', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    final candidates = [
      '${Directory.current.path}/native/build/bin/llama-cli',
      '${Directory.current.path}/../native/build/bin/llama-cli',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Call after profile knobs that affect context size / backend choice change.
  void invalidateCachedEngine() {
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
