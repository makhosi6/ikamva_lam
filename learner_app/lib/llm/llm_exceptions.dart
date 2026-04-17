/// Native CLI or model path is missing / invalid.
class LlmUnavailableException implements Exception {
  LlmUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'LlmUnavailableException: $message';
}

/// Load or inference exceeded budget (memory / time).
class LlmResourceException implements Exception {
  LlmResourceException(this.message);

  final String message;

  @override
  String toString() => 'LlmResourceException: $message';
}
