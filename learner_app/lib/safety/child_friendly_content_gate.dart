import 'dart:convert';

import '../hub/daily_quest_ids.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_output_filters.dart';
import '../llm/llm_service.dart';
import '../prompts/prompt_compliance.dart';

/// Result of on-device **child-appropriate** screening (spec §4.1.4).
///
/// Combines **rule-based** checks with an optional **Gemma** JSON sentiment
/// pass (`TASK: child_content_sentiment_check`).
class ContentSafetyVerdict {
  const ContentSafetyVerdict({required this.ok, this.violations = const []});

  final bool ok;
  final List<String> violations;
}

/// Heuristic + **Gemma** gate for **primary-school–appropriate** learner content.
///
/// Covers: hub topics, quest topics, **all string fields** in task JSON,
/// multilingual hint maps, and Teacher/Parent insight text.
abstract final class ChildFriendlyContentGate {
  static const int maxTopicLength = 48;
  static const int maxTopicWords = 5;

  /// Marker matched by [StubLlmEngine] for deterministic CI output.
  static const sentimentTaskMarker = 'TASK: child_content_sentiment_check';

  static const Set<String> _blockedWholeWords = {
    'ass',
    'asshole',
    'bastard',
    'bitch',
    'bomb',
    'bullshit',
    'cocaine',
    'crap',
    'cunt',
    'damn',
    'dick',
    'drugs',
    'fuck',
    'fucking',
    'heroin',
    'hitler',
    'kill',
    'meth',
    'nazi',
    'penis',
    'porn',
    'porno',
    'rape',
    'sex',
    'shit',
    'slut',
    'suicide',
    'vagina',
    'weapon',
    'whore',
  };

  static final RegExp _urlLike = RegExp(
    r'https?:\/\/|www\.|\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b',
    caseSensitive: false,
  );

  // --- Rules-only (sync), for fast reject and unit tests -----------------

  /// Rules only — no Gemma call (tests, or inner fast path).
  static ContentSafetyVerdict evaluateTopicPhraseRules(String raw) {
    final t = DailyQuestIds.normalizeTopicToken(raw);
    final violations = <String>[];
    if (t.isEmpty) {
      violations.add('topic_empty');
      return ContentSafetyVerdict(ok: false, violations: violations);
    }
    if (t.length > maxTopicLength) {
      violations.add('topic_too_long');
    }
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > maxTopicWords) {
      violations.add('topic_too_many_words');
    }
    violations.addAll(_scanPlainText(t, context: 'topic'));
    return ContentSafetyVerdict(
      ok: violations.isEmpty,
      violations: violations,
    );
  }

  static ContentSafetyVerdict evaluatePlainTextRules(String text, {String context = 'text'}) {
    final violations = _scanPlainText(text, context: context);
    return ContentSafetyVerdict(ok: violations.isEmpty, violations: violations);
  }

  static ContentSafetyVerdict evaluateJsonPayloadStringRules(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      return evaluateJsonValueRules(decoded);
    } on FormatException catch (e) {
      return ContentSafetyVerdict(
        ok: false,
        violations: ['json_decode:${e.message}'],
      );
    }
  }

  static ContentSafetyVerdict evaluateJsonValueRules(Object? value, {String path = ''}) {
    if (value == null) return const ContentSafetyVerdict(ok: true);
    if (value is String) {
      return evaluatePlainTextRules(value, context: path.isEmpty ? 'json' : path);
    }
    if (value is num || value is bool) {
      return const ContentSafetyVerdict(ok: true);
    }
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final v = evaluateJsonValueRules(value[i], path: '$path[$i]');
        if (!v.ok) return v;
      }
      return const ContentSafetyVerdict(ok: true);
    }
    if (value is Map) {
      for (final e in value.entries) {
        final key = e.key.toString();
        final v = evaluateJsonValueRules(
          e.value,
          path: path.isEmpty ? key : '$path.$key',
        );
        if (!v.ok) return v;
      }
      return const ContentSafetyVerdict(ok: true);
    }
    return const ContentSafetyVerdict(ok: true);
  }

  static void _collectStrings(Object? value, List<String> out) {
    if (value == null) return;
    if (value is String) {
      final t = value.trim();
      if (t.isNotEmpty) out.add(t);
      return;
    }
    if (value is Map) {
      for (final e in value.values) {
        _collectStrings(e, out);
      }
      return;
    }
    if (value is List) {
      for (final e in value) {
        _collectStrings(e, out);
      }
    }
  }

  /// Concatenated string leaves for one Gemma sentiment pass.
  static String materialBlobFromJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      final parts = <String>[];
      _collectStrings(decoded, parts);
      return parts.join('\n---\n');
    } on Object {
      return '';
    }
  }

  // --- Gemma sentiment (async) -------------------------------------------

  /// Hub topic line + Gemma sentiment (single phrase).
  static Future<ContentSafetyVerdict> evaluateTopicPhrase(String raw) async {
    final rules = evaluateTopicPhraseRules(raw);
    if (!rules.ok) return rules;
    final t = DailyQuestIds.normalizeTopicToken(raw);
    return _applySentiment(rules, 'topic', t);
  }

  /// One Gemma call for several hub themes (after rules passed per item).
  static Future<ContentSafetyVerdict> evaluateHubTopicsBatchSentiment(
    List<String> normalizedTopics,
  ) async {
    if (normalizedTopics.isEmpty) {
      return const ContentSafetyVerdict(ok: true);
    }
    final encoded = jsonEncode(normalizedTopics);
    return _sentimentLlm(
      'hub_topic_batch',
      'ITEMS_JSON (array of short theme titles):\n$encoded',
    );
  }

  /// Full task payload: rules on every string, then **one** Gemma pass on all text.
  static Future<ContentSafetyVerdict> evaluateJsonPayloadString(
    String jsonString,
  ) async {
    final rules = evaluateJsonPayloadStringRules(jsonString);
    if (!rules.ok) return rules;
    final blob = materialBlobFromJsonString(jsonString);
    if (blob.trim().isEmpty) return rules;
    return _applySentiment(rules, 'task_payload', blob);
  }

  /// Free text with Gemma (e.g. bundled hint fields).
  static Future<ContentSafetyVerdict> evaluatePlainText(
    String text, {
    String context = 'text',
  }) async {
    final rules = evaluatePlainTextRules(text, context: context);
    if (!rules.ok) return rules;
    return _applySentiment(rules, context, text);
  }

  /// Recurses JSON then runs rules; if OK, one Gemma call on joined strings.
  static Future<ContentSafetyVerdict> evaluateJsonValue(Object? value) async {
    final rules = evaluateJsonValueRules(value);
    if (!rules.ok) return rules;
    final parts = <String>[];
    _collectStrings(value, parts);
    final blob = parts.join('\n---\n');
    if (blob.trim().isEmpty) return rules;
    return _applySentiment(rules, 'json_tree', blob);
  }

  static Future<ContentSafetyVerdict> _applySentiment(
    ContentSafetyVerdict rules,
    String kind,
    String material,
  ) async {
    if (!rules.ok) return rules;
    final m = material.trim();
    if (m.isEmpty) return rules;
    final cap = m.length > 2200 ? '${m.substring(0, 2200)}\n…' : m;
    final sent = await _sentimentLlm(kind, cap);
    if (sent.ok) return rules;
    return ContentSafetyVerdict(
      ok: false,
      violations: [...rules.violations, ...sent.violations],
    );
  }

  static Future<ContentSafetyVerdict> _sentimentLlm(
    String kind,
    String material,
  ) async {
    try {
      final prompt = '''
$sentimentTaskMarker
KIND: ${jsonEncode(kind)}
The following is learner-facing English-learning material. Decide if it is **wholesome and appropriate for children about 8–14** in a school setting (no sexual content, graphic violence, hate, slurs, self-harm encouragement, illegal drugs, grooming, extremism, or toxic bullying). Neutral educational English is **safe**.

CONTENT:
$material

OUTPUT JSON ONLY (no markdown):
{"safe": true}
or
{"safe": false, "reason": "one short English phrase"}
If unsure, prefer safe=false.
''';
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: prompt, maxTokens: 96),
      );
      if (isEmptyComplianceObject(raw)) {
        return const ContentSafetyVerdict(
          ok: false,
          violations: ['gemma_sentiment:model_refused'],
        );
      }
      final span = LlmOutputFilters.takeThroughFirstBalancedJson(raw.trim());
      final decoded = jsonDecode(span);
      if (decoded is! Map<String, dynamic>) {
        return const ContentSafetyVerdict(
          ok: false,
          violations: ['gemma_sentiment:bad_json_shape'],
        );
      }
      final safe = decoded['safe'] == true;
      if (safe) return const ContentSafetyVerdict(ok: true);
      final rawReason = decoded['reason'];
      final reason = rawReason is String && rawReason.trim().isNotEmpty
          ? rawReason.trim()
          : 'unsafe';
      return ContentSafetyVerdict(
        ok: false,
        violations: ['gemma_sentiment:$reason'],
      );
    } on Object catch (e) {
      return ContentSafetyVerdict(
        ok: false,
        violations: ['gemma_sentiment:error:$e'],
      );
    }
  }

  static List<String> _scanPlainText(String text, {required String context}) {
    final violations = <String>[];
    if (text.length > 4000) {
      violations.add('${context}_too_long');
      return violations;
    }
    if (_urlLike.hasMatch(text)) {
      violations.add('${context}_url_or_email');
    }
    final lower = text.toLowerCase();
    for (final w in _tokens(lower)) {
      if (_blockedWholeWords.contains(w)) {
        violations.add('${context}_blocked:$w');
      }
    }
    return violations;
  }

  static Iterable<String> _tokens(String lower) sync* {
    for (final m in RegExp(r'[a-z0-9]+').allMatches(lower)) {
      yield m.group(0)!;
    }
  }
}
