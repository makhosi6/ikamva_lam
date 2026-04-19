import 'dart:convert';
import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../data/insight_card_repository.dart';
import '../db/app_database.dart';
import '../db/seed.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_output_filters.dart';
import '../llm/llm_service.dart';
import '../prompts/prompt_composer.dart';
import '../safety/child_friendly_content_gate.dart';
import 'weak_skills_detector.dart';

/// Persists one AI insight card from local aggregates (TASKS §11.3).
class InsightJob {
  InsightJob._();

  static final _uuid = Uuid();

  static Future<void> runAfterSession(IkamvaDatabase db, String sessionId) async {
    final weak = await WeakSkillsDetector(db).detect(maxAttempts: 48);
    if (weak.isEmpty) return;
    final stats = <String, Object?>{
      'session_id': sessionId,
      'weak_skills': [
        for (final w in weak)
          {
            'skill': w.skillId,
            'accuracy': w.accuracy,
            'attempts': w.attempts,
          },
      ],
    };
    try {
      final prompt = await PromptComposer().composeInsightPrompt(
        jsonEncode(stats),
      );
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: prompt),
      );
      final span = LlmOutputFilters.takeThroughFirstBalancedJson(raw.trim());
      final map = jsonDecode(span);
      if (map is! Map<String, dynamic>) return;
      final issue = _stringField(map, 'issue', 'Practice focus');
      final pattern = _stringField(map, 'pattern', 'Mixed errors across skills.');
      final rec = _stringField(
        map,
        'recommendation',
        'Short review games on weak strands.',
      );
      final gate = await ChildFriendlyContentGate.evaluateJsonValue({
        'issue': issue,
        'pattern': pattern,
        'recommendation': rec,
      });
      if (!gate.ok) {
        developer.log(
          'InsightJob: insight text failed child-friendly gate → '
          '${gate.violations}',
          name: 'InsightJob',
        );
        return;
      }
      await InsightCardRepository(db).insert(
        InsightCardsCompanion.insert(
          id: 'ins-${_uuid.v4()}',
          learnerId: kSeedLearnerId,
          issue: issue,
          pattern: pattern,
          recommendation: rec,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } on Object {
      // Offline / stub LLM: skip silently
    }
  }

  static String _stringField(
    Map<String, dynamic> map,
    String key,
    String fallback,
  ) {
    final v = map[key];
    if (v is String) {
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
    return fallback;
  }
}
