import 'dart:convert';

import '../hub/daily_quest_ids.dart';

/// Result of on-device **child-appropriate** screening (spec §4.1.4).
///
/// Rule-based only (no extra model call). Intended to catch obvious unsafe
/// tokens before JSON is persisted or shown.
class ContentSafetyVerdict {
  const ContentSafetyVerdict({required this.ok, this.violations = const []});

  final bool ok;
  final List<String> violations;
}

/// Heuristic gate for **primary-school–appropriate** English learning content.
///
/// Used for: hub topic strings, task payload JSON string fields, Teacher/Parent
/// quest topic input. Not a substitute for supervision; extend lists as needed.
abstract final class ChildFriendlyContentGate {
  /// Max length for a single topic phrase (normalized).
  static const int maxTopicLength = 48;

  /// Max words in a hub topic phrase.
  static const int maxTopicWords = 5;

  /// Whole-word blocklist (lowercase). Keep conservative to limit false positives.
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

  /// Hub / quest **topic** token (short phrase, letters + spaces).
  static ContentSafetyVerdict evaluateTopicPhrase(String raw) {
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

  /// Any JSON-serializable value: recurse maps/lists; check every string leaf.
  static ContentSafetyVerdict evaluateJsonValue(Object? value, {String path = ''}) {
    if (value == null) return const ContentSafetyVerdict(ok: true);
    if (value is String) {
      return evaluatePlainText(value, context: path.isEmpty ? 'json' : path);
    }
    if (value is num || value is bool) {
      return const ContentSafetyVerdict(ok: true);
    }
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final v = evaluateJsonValue(value[i], path: '$path[$i]');
        if (!v.ok) return v;
      }
      return const ContentSafetyVerdict(ok: true);
    }
    if (value is Map) {
      for (final e in value.entries) {
        final key = e.key.toString();
        final v = evaluateJsonValue(e.value, path: path.isEmpty ? key : '$path.$key');
        if (!v.ok) return v;
      }
      return const ContentSafetyVerdict(ok: true);
    }
    return const ContentSafetyVerdict(ok: true);
  }

  static ContentSafetyVerdict evaluateJsonPayloadString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      return evaluateJsonValue(decoded);
    } on FormatException catch (e) {
      return ContentSafetyVerdict(
        ok: false,
        violations: ['json_decode:${e.message}'],
      );
    }
  }

  /// Free text (hints, sentences, options, etc.).
  static ContentSafetyVerdict evaluatePlainText(String text, {String context = 'text'}) {
    final violations = _scanPlainText(text, context: context);
    return ContentSafetyVerdict(ok: violations.isEmpty, violations: violations);
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
