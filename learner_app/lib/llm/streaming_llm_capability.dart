import 'llm_generate_request.dart';

/// Optional capability for **streaming** partial model text to the UI ([spec.md](../../../spec.md) §7.3).
///
/// **Status:** not implemented on any engine yet — see [TASKS.md](../../../TASKS.md) Phase 17.
/// [ProcessLlmEngine] remains batch (`Future<String>`) until one of:
/// - `llama-cli` (or wrapper) exposes line-delimited / token stdout and a Dart consumer, or
/// - `dart:ffi` + `libllama` with native streaming callbacks.
///
/// Callers should use [LlmService.tryOpenGenerateStream] and fall back to [LlmService.generate]
/// when the return value is null.
abstract interface class StreamingLlmCapability {
  /// Fragments as emitted (implementation-defined: tokens, words, or lines).
  ///
  /// The stream must complete when generation ends or errors; do not leave dangling natives.
  Stream<String> generateChunkStream(LlmGenerateRequest request);
}
