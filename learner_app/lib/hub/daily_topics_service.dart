import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import 'daily_quest_ids.dart';

/// One row on the hub: canonical [topic] for DB / routes, [label] for display.
class HubTopicOffer {
  const HubTopicOffer({required this.topic, required this.label});

  final String topic;
  final String label;
}

/// Picks a small set of practice topics per calendar day (LLM when available,
/// deterministic fallback otherwise). Cached in [SharedPreferences] per day.
abstract final class DailyTopicsService {
  static const _prefsKey = 'hub_daily_topics_v1';
  static const _topicCount = 4;

  static const _fallbackPool = <String>[
    'food',
    'family',
    'travel',
    'school',
    'weather',
    'shopping',
    'health',
    'sports',
    'work',
    'home',
    'friends',
    'animals',
    'music',
    'time',
    'colors',
    'numbers',
    'body',
    'clothes',
    'city',
    'nature',
  ];

  static String calendarDayKeyLocal([DateTime? now]) {
    final n = (now ?? DateTime.now()).toLocal();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<List<HubTopicOffer>> loadOffersForToday() async {
    final dayKey = calendarDayKeyLocal();
    final p = await SharedPreferences.getInstance();
    final cached = p.getString(_prefsKey);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        if (map['day'] == dayKey && map['topics'] is List) {
          final list = (map['topics'] as List).cast<String>();
          return _asOffers(_dedupeTopics(list.map(DailyQuestIds.normalizeTopicToken)));
        }
      } on Object {
        // ignore bad cache
      }
    }

    final topics = await _generateOrFallback(dayKey);
    await p.setString(
      _prefsKey,
      jsonEncode({'day': dayKey, 'topics': topics}),
    );
    return _asOffers(topics);
  }

  static List<HubTopicOffer> _asOffers(List<String> topics) {
    return [
      for (final t in topics) HubTopicOffer(topic: t, label: _titleCase(t)),
    ];
  }

  static String _titleCase(String topic) {
    return topic
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1)}';
        })
        .join(' ');
  }

  static Future<List<String>> _generateOrFallback(String dayKey) async {
    final fromLlm = await _tryLlmTopics();
    if (fromLlm != null && fromLlm.length >= _topicCount) {
      return fromLlm.take(_topicCount).toList();
    }
    final seeds = fromLlm ?? const <String>[];
    return _fallbackForDay(dayKey, seeds: seeds);
  }

  static Future<List<String>?> _tryLlmTopics() async {
    try {
      const prompt =
          'Return only a JSON array of exactly 4 different strings. '
          'Each string is a short English-learning topic for A1 adult learners '
          '(one or two words, lowercase letters only, no punctuation). '
          'Example: ["food","travel","family","work"]. No markdown, no extra text.';
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: prompt, maxTokens: 120),
      );
      final slice = _extractJsonArray(raw) ?? raw.trim();
      final decoded = jsonDecode(slice);
      if (decoded is! List) return null;
      final out = <String>[];
      for (final e in decoded) {
        if (e is! String) continue;
        final t = DailyQuestIds.normalizeTopicToken(
          e.replaceAll(RegExp(r'[^a-zA-Z\s]'), ' '),
        );
        if (t.isNotEmpty) out.add(t);
      }
      return _dedupeTopics(out);
    } on Object {
      return null;
    }
  }

  /// First `[` … `]` span with balanced brackets.
  static String? _extractJsonArray(String raw) {
    final start = raw.indexOf('[');
    if (start < 0) return null;
    var depth = 0;
    for (var i = start; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c == 0x5B) {
        depth++;
      } else if (c == 0x5D) {
        depth--;
        if (depth == 0) {
          return raw.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  static List<String> _dedupeTopics(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final t in raw) {
      final n = DailyQuestIds.normalizeTopicToken(t);
      if (n.isEmpty || seen.contains(n)) continue;
      seen.add(n);
      out.add(n);
    }
    return out;
  }

  static List<String> _fallbackForDay(String dayKey, {List<String> seeds = const []}) {
    final out = _dedupeTopics(seeds);
    final pool = List<String>.from(_fallbackPool)
      ..shuffle(Random(dayKey.hashCode));
    for (final p in pool) {
      if (out.length >= _topicCount) break;
      if (!out.contains(p)) out.add(p);
    }
    var i = 0;
    while (out.length < _topicCount) {
      final p = pool[i % pool.length];
      if (!out.contains(p)) out.add(p);
      i++;
    }
    return out.take(_topicCount).toList();
  }
}
