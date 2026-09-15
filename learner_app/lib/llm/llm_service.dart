import 'dart:async';

import 'package:flutter/foundation.dart';

import '../debug/agent_debug_log.dart';
import '../state/settings_store.dart';
import 'flutter_gemma_llm_engine.dart';
import 'host_is_android.dart';
import 'llm_engine.dart';
import 'llm_exceptions.dart';
import 'llm_generate_request.dart';
import 'llm_limits.dart';
import 'model_diagnostics.dart';
import 'native_llm_platform.dart';
import 'streaming_llm_capability.dart';

/// App-wide access to on-device LLM (TASKS §6.4–6.8).
///
/// Uses [FlutterGemmaLlmEngine]: **Gemma 3n or Gemma 4** from Hugging Face to
/// app documents, then **native MethodChannel** (LiteRT-LM on Android, MediaPipe
/// on iOS).
///
/// Removed: `ProcessLlmEngine` / `llama-cli` / GGUF / `native/build` paths.
class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  SettingsStore? _settings;
  LlmEngine? _engine;
  bool _disposed = false;

  /// Serializes native load/close so [invalidateCachedEngine] cannot interleave
  /// with an in-flight [ensureLoaded] / GPU init (post-download crash on some GPUs).
  Future<void> _serializedChain = Future<void>.value();

  Future<T> _runSerialized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _serializedChain = _serializedChain.then((_) async {
      try {
        final r = await fn();
        if (!completer.isCompleted) completer.complete(r);
      } on Object catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Shared with [FlutterGemmaLlmEngine] so [configure] can add/remove UI
  /// callbacks without [invalidateCachedEngine].
  final LlmInstallUiHooks _installUiHooks = LlmInstallUiHooks();

  /// `true` after [ensureReady] finishes and the on-device weights are loaded
  /// ([engine.ensureLoaded] completed). Resets to `false` when
  /// [invalidateCachedEngine] runs. Use with [ValueListenableBuilder] or
  /// [Listenable.merge] so any page can react without calling the LLM again.
  final ValueNotifier<bool> onDeviceWeightsReady = ValueNotifier<bool>(false);

  /// Optional: [onModelInstallProgress] 0–100 during bytes transfer;
  /// [onModelLifecycle] verbose steps for UI (phase label + message + optional %).
  ///
  /// Install / lifecycle hooks are stored on [_installUiHooks] and picked up by
  /// the cached engine — no discard when only callbacks change (avoids tearing
  /// down a load started before the hub attaches progress UI).
  void configure(
    SettingsStore settings, {
    void Function(int installPercent)? onModelInstallProgress,
    void Function(String phase, String message, int? percent)? onModelLifecycle,
  }) {
    _settings = settings;
    _installUiHooks.onInstallProgress = onModelInstallProgress;
    _installUiHooks.onLifecycle = onModelLifecycle;
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'configure',
      message: 'Configured LLM service',
      data: <String, Object?>{'lowRam': settings.lowRamProfile},
    );
  }

  /// Validates engine + on-disk model (re-downloads from Hugging Face if needed).
  Future<void> ensureReady() async {
    _throwIfDisposed();
    // #region agent log
    agentDebugLog(
      location: 'llm_service.dart:ensureReady',
      message: 'ensureReady called',
      hypothesisId: 'A',
      runId: 'post-fix',
      data: <String, Object?>{
        'hasCachedEngine': _engine != null,
        'weightsReady': onDeviceWeightsReady.value,
      },
    );
    // #endregion
    await _runSerialized(() async {
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
    });
  }

  /// Same as [configure] with **only** [settings]: clears install/lifecycle
  /// hooks **without** disposing the cached engine. Call after the home hub has
  /// finished warming so other routes keep using the loaded weights.
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

    final engine = await _runSerialized(() async {
      final e = _engine ??= _createEngine();
      await e.ensureLoaded();
      return e;
    });
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'generate',
      message: 'Run one-shot generation',
      data: <String, Object?>{'maxTokens': maxNew, 'context': ctx},
    );
    try {
      final completion = await engine
          .generate(resolved)
          .timeout(
            const Duration(seconds: 180),
            onTimeout: () => throw LlmResourceException(
              'Generation timed out. Try Low RAM mode in Settings or a shorter activity.',
            ),
          );
      // #region agent log
      agentDebugLog(
        location: 'llm_service.dart:generate',
        message: 'generate ok',
        hypothesisId: 'H4',
        runId: 'post-fix',
        data: <String, Object?>{
          'ctx': ctx,
          'maxNew': maxNew,
          'promptChars': resolved.prompt.text.length,
          'outChars': completion.text.length,
          'hostIsAndroid': hostIsAndroid,
          'defaultTargetPlatform': defaultTargetPlatform.name,
        },
      );
      // #endregion
      return completion;
    } on Object catch (e) {
      // #region agent log
      agentDebugLog(
        location: 'llm_service.dart:generate',
        message: 'generate failed',
        hypothesisId: 'H4',
        runId: 'post-fix',
        data: <String, Object?>{
          'ctx': ctx,
          'maxNew': maxNew,
          'promptChars': resolved.prompt.text.length,
          'error': e.toString(),
          'hostIsAndroid': hostIsAndroid,
          'defaultTargetPlatform': defaultTargetPlatform.name,
        },
      );
      // #endregion
      rethrow;
    }
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

    final engine = await _runSerialized(() async {
      final e = _engine ??= _createEngine();
      await e.ensureLoaded();
      return e;
    });
    ModelDiagnostics.instance.log(
      area: 'service',
      action: 'generate_stream_open',
      message: 'Open stream generation',
      data: <String, Object?>{'maxTokens': maxNew, 'context': ctx},
    );
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
      installUiHooks: _installUiHooks,
    );
  }

  /// Call after profile knobs that affect context size / backend choice change.
  ///
  /// Awaits native [NativeLlmPlatform.closeModel] so the next load cannot start
  /// while a previous GPU init is still running.
  Future<void> invalidateCachedEngine() {
    // #region agent log
    agentDebugLog(
      location: 'llm_service.dart:invalidateCachedEngine',
      message: 'invalidateCachedEngine',
      hypothesisId: 'A',
      runId: 'post-fix',
      data: <String, Object?>{
        'hadEngine': _engine != null,
        'weightsReady': onDeviceWeightsReady.value,
        'stack': StackTrace.current.toString().split('\n').take(6).join(' | '),
      },
    );
    // #endregion
    return _runSerialized(() async {
      ModelDiagnostics.instance.log(
        area: 'service',
        action: 'invalidate_cache',
        message: 'Invalidated engine cache',
      );
      final old = _engine;
      _engine = null;
      onDeviceWeightsReady.value = false;
      old?.dispose();
      if (shouldUseFlutterGemmaEngine) {
        try {
          await NativeLlmPlatform.closeModel();
        } on Object {
          // Tests / missing plugin: best-effort only.
        }
      }
    });
  }

  void dispose() {
    _disposed = true;
    unawaited(
      _runSerialized(() async {
        _engine?.dispose();
        _engine = null;
        if (shouldUseFlutterGemmaEngine) {
          try {
            await NativeLlmPlatform.closeModel();
          } on Object {
            // ignore
          }
        }
      }),
    );
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('LlmService disposed');
    }
  }
}
