import 'llm_generate_request.dart';

/// Pluggable on-device backend (TASKS §6.5 / §6.8).
abstract class LlmEngine {
  /// Validates paths / allocates native handles.
  Future<void> ensureLoaded();

  /// Returns model text (often JSON) for one completion.
  Future<String> generate(LlmGenerateRequest request);

  /// Releases native resources or cached handles.
  void dispose();
}
