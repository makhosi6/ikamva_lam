import 'llm_generate_request.dart';

/// Pluggable on-device backend (TASKS §6.5 / §6.8).
///
/// Optional **streaming** for spec §7.3: engines may also implement
/// `StreamingLlmCapability` (see `LlmService.tryOpenGenerateStream` in `llm_service.dart`).
abstract class LlmEngine {
  /// Validates paths / allocates native handles.
  Future<void> ensureLoaded();

  /// Returns model text (often JSON) for one completion.
  Future<ModelBoundCompletion> generate(LlmGenerateRequest request);

  /// Releases native resources or cached handles.
  void dispose();
}
