/// Parameters for one completion (TASKS §6.5).
class LlmGenerateRequest {
  const LlmGenerateRequest({
    required this.prompt,
    this.maxTokens,
    this.stopSequences = const [],
    this.contextSize,
  });

  final String prompt;

  /// Max new tokens; when null, engine defaults apply.
  final int? maxTokens;

  /// Optional stop strings (best-effort for CLI; always applied in post-process).
  final List<String> stopSequences;

  /// Context size in tokens; when null, profile defaults apply.
  final int? contextSize;
}
