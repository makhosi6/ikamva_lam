import 'dart:async';

import 'package:flutter/services.dart';

/// Method/Event channels to native **LiteRT-LM** (Android `.litertlm`) and
/// **MediaPipe GenAI** `LlmInference` (iOS), keyed by absolute [modelPath].
abstract final class NativeLlmPlatform {
  static const MethodChannel _method =
      MethodChannel('za.co.ikamvalam/native_llm');
  static const EventChannel _stream =
      EventChannel('za.co.ikamvalam/native_llm_stream');

  /// Queues native load/close so [probeFlutterGemmaActiveModelReady] (and any
  /// future caller) cannot run `loadModel`/`closeModel` in parallel with
  /// [LlmService] warm-up on a second isolate/timer of execution.
  static Future<void> _nativeLoadCloseChain = Future<void>.value();

  static Future<T> _runLoadCloseSerialized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _nativeLoadCloseChain = _nativeLoadCloseChain.then((_) async {
      try {
        final r = await fn();
        if (!completer.isCompleted) completer.complete(r);
      } on Object catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<void> loadModel(Map<String, Object?> args) async {
    await _runLoadCloseSerialized(
      () => _method.invokeMethod<void>('loadModel', args),
    );
  }

  static Future<void> closeModel() async {
    await _runLoadCloseSerialized(
      () => _method.invokeMethod<void>('closeModel'),
    );
  }

  /// One-shot completion (native builds a fresh session per call).
  static Future<String> generate(Map<String, Object?> args) async {
    final r = await _method.invokeMethod<String>('generate', args);
    return r ?? '';
  }

  /// Token deltas from native async generation.
  static Stream<String> generateStream(Map<String, Object?> args) {
    return _stream.receiveBroadcastStream(args).map(mapNativeLlmStreamEvent);
  }
}

/// Maps one EventChannel payload to a token string (Requirement 8.3, 8.4).
///
/// Supports plain [String] chunks, `{ "token": String }`, and throws for
/// `{ "error": ... }`.
String mapNativeLlmStreamEvent(Object? event) {
  if (event is Map) {
    final err = event['error'];
    if (err != null) {
      throw PlatformException(
        code: 'native_llm_stream',
        message: err.toString(),
      );
    }
    final t = event['token'];
    if (t != null) return t.toString();
    return '';
  }
  if (event is String) return event;
  return event.toString();
}
