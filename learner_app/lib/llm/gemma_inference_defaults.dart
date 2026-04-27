/// Sampling defaults aligned with common on-device Gemma chat examples
/// (temperature ~0.8, topK ~40, topP ~0.95).
abstract final class GemmaInferenceDefaults {
  static const double temperature = 0.8;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int randomSeed = 1;
  static const bool enableThinking = false;
}
