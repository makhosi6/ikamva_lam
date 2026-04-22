import 'llm_generate_request.dart';

/// Optional capability for **streaming** partial model text to the UI ([spec.md](../../../spec.md) §7.3).
///
/// **Status:** [FlutterGemmaLlmEngine] implements this on Android/iOS using the
/// plugin async token stream. If the active engine does not implement this
/// interface, [LlmService.tryOpenGenerateStream] returns `null`.
///
/// Callers should use [LlmService.tryOpenGenerateStream] and fall back to [LlmService.generate]
/// when the return value is null.
abstract interface class StreamingLlmCapability {
  /// **Model-bound** output fragments as emitted (tokens / chunks from the same
  /// [LlmGenerateRequest.prompt] session — not mixed with non-model sources).
  ///
  /// The stream must complete when generation ends or errors; do not leave dangling natives.
  Stream<String> generateChunkStream(LlmGenerateRequest request);
}
