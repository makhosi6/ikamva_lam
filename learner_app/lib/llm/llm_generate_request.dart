import 'package:flutter/foundation.dart';

/// Text that is intended **only** as input to the on-device LLM ([LlmEngine] /
/// [LlmService]). Wrap prompt strings at the boundary where they are composed
/// for inference — do not pass arbitrary UI copy here without composing a
/// proper generation prompt first.
@immutable
final class ModelBoundPrompt {
  const ModelBoundPrompt(this.text);
  final String text;
}

/// One full completion string **from** the active [LlmEngine] after template
/// / stop-sequence handling inside the engine (still subject to gates and
/// parsers before learner-facing display).
@immutable
final class ModelBoundCompletion {
  const ModelBoundCompletion(this.text);
  final String text;
}

/// Parameters for one completion (TASKS §6.5).
class LlmGenerateRequest {
  const LlmGenerateRequest({
    required this.prompt,
    this.maxTokens,
    this.stopSequences = const [],
    this.contextSize,
  });

  final ModelBoundPrompt prompt;

  /// Max new tokens; when null, engine defaults apply.
  final int? maxTokens;

  /// Optional stop strings (best-effort for CLI; always applied in post-process).
  final List<String> stopSequences;

  /// Context size in tokens; when null, profile defaults apply.
  final int? contextSize;
}
