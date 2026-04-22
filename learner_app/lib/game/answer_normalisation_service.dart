import 'dart:convert';

import '../domain/tasks/cloze_payload.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_output_filters.dart';
import '../llm/llm_service.dart';
import '../prompts/prompt_composer.dart';
import 'rule_based_evaluator.dart';

/// Spec §5.2 — maps mixed-language learner text to English for rule scoring.
abstract final class AnswerNormalisationService {
  /// Returns a canonical English string from the model, or null on failure.
  static Future<String?> tryCanonicalEn({
    required String taskPayloadJson,
    required String learnerText,
  }) async {
    final trimmed = learnerText.trim();
    if (trimmed.isEmpty) return null;

    final prompt = await PromptComposer().composeNormaliseAnswerPrompt(
      taskJson: taskPayloadJson,
      learnerText: trimmed,
    );
    final raw = await LlmService.instance.generate(
      LlmGenerateRequest(prompt: ModelBoundPrompt(prompt), maxTokens: 96),
    );
    final slice = LlmOutputFilters.takeThroughFirstBalancedJson(raw.text);
    try {
      final decoded = jsonDecode(slice);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final v = map['canonical_en'];
      if (v is! String) return null;
      final out = v.trim();
      if (out.isEmpty || out == '{}') return null;
      if (out.length > 120) return null;
      return out;
    } on Object {
      return null;
    }
  }

  /// After [tryCanonicalEn], pick a cloze chip label if it matches the answer
  /// or any option (case-insensitive).
  static String? matchingClozeOption({
    required ClozePayload payload,
    required String canonical,
  }) {
    final n = RuleBasedEvaluator.normalizeAnswerToken(canonical);
    if (n.isEmpty) return null;
    if (RuleBasedEvaluator.normalizeAnswerToken(payload.answer) == n) {
      return payload.answer;
    }
    for (final o in payload.options) {
      if (RuleBasedEvaluator.normalizeAnswerToken(o) == n) return o;
    }
    return null;
  }
}
