import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/learner_content_policy.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import '../safety/child_friendly_content_gate.dart';
import 'daily_quest_ids.dart';

/// One row on the hub: canonical [topic] for DB / routes, [label] for display.
class HubTopicOffer {
  const HubTopicOffer({required this.topic, required this.label});

  final String topic;
  final String label;
}

/// Picks practice topics for the hub: **model-generated** in production, with
/// [ChildFriendlyContentGate] on every string. Cached per calendar day.
abstract final class DailyTopicsService {
  /// Bump when topic policy changes (invalidates prefs cache).
  static const _prefsKey = 'hub_daily_topics_v3';
  static const _topicCount = 8;

  /// Dev-only fallback when LLM unavailable (see [LearnerContentPolicy.allowDevSeed]).
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
          final normalized =
              _dedupeTopics(list.map(DailyQuestIds.normalizeTopicToken));
          final ruleOk = <String>[];
          for (final t in normalized) {
            if (ChildFriendlyContentGate.evaluateTopicPhraseRules(t).ok) {
              ruleOk.add(t);
            }
          }
          if (ruleOk.isNotEmpty) {
            final sent =
                await ChildFriendlyContentGate.evaluateHubTopicsBatchSentiment(
              ruleOk,
            );
            if (sent.ok) {
              return _asOffers(ruleOk);
            }
            await p.remove(_prefsKey);
          }
        }
      } on Object {
        // ignore bad cache
      }
    }

    final topics = await _generateTopics(dayKey);
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

  /// Production: only **AI** topics that pass the child-friendly gate (may be
  /// fewer than [_topicCount]). Dev/profile with [LearnerContentPolicy.allowDevSeed]:
  /// may pad from a small curated pool if the model returns nothing usable.
  static Future<List<String>> _generateTopics(String dayKey) async {
    final accumulated = <String>[];
    final seen = <String>{};
    for (var attempt = 0;
        attempt < 4 && accumulated.length < _topicCount;
        attempt++) {
      final batch = await _tryLlmTopics();
      if (batch == null) continue;
      final candidates = <String>[];
      for (final t in batch) {
        final vr = ChildFriendlyContentGate.evaluateTopicPhraseRules(t);
        if (!vr.ok) {
          developer.log(
            'DailyTopicsService: topic rules reject "$t" → ${vr.violations}',
            name: 'DailyTopicsService',
          );
          continue;
        }
        candidates.add(t);
      }
      if (candidates.isEmpty) continue;
      final batchSentiment =
          await ChildFriendlyContentGate.evaluateHubTopicsBatchSentiment(
        candidates,
      );
      if (!batchSentiment.ok) {
        developer.log(
          'DailyTopicsService: Gemma rejected topic batch → '
          '${batchSentiment.violations}',
          name: 'DailyTopicsService',
        );
        continue;
      }
      for (final t in candidates) {
        if (seen.add(t)) accumulated.add(t);
        if (accumulated.length >= _topicCount) break;
      }
    }
    if (accumulated.length >= _topicCount) {
      return accumulated.take(_topicCount).toList();
    }
    if (LearnerContentPolicy.allowDevSeed) {
      return await _fallbackForDay(dayKey, seeds: accumulated);
    }
    return accumulated;
  }

  static Future<List<String>?> _tryLlmTopics() async {
    try {
      const prompt =
          'Return only a JSON array of exactly 8 different strings. '
          'Each string is one short English-learning **topic title** for children '
          'ages about 8–14 in a South African classroom (wholesome, no romance, '
          'no violence, no drugs, no politics, no religion debates, no brands, '
          'no URLs). Use lowercase letters and single spaces only, max 5 words '
          'per string. Example shape: '
          '["food","travel","family","school","weather","music","sports","home"]. '
          'No markdown, no commentary, no extra keys.';
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: prompt, maxTokens: 220),
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

  static Future<List<String>> _fallbackForDay(
    String dayKey, {
    List<String> seeds = const [],
  }) async {
    final out = _dedupeTopics(seeds);
    final pool = List<String>.from(_fallbackPool)
      ..shuffle(Random(dayKey.hashCode));
    for (final p in pool) {
      if (out.length >= _topicCount) break;
      if (!out.contains(p) &&
          ChildFriendlyContentGate.evaluateTopicPhraseRules(p).ok) {
        out.add(p);
      }
    }
    var i = 0;
    while (out.length < _topicCount) {
      final p = pool[i % pool.length];
      if (!out.contains(p)) out.add(p);
      i++;
    }
    final trimmed = out.take(_topicCount).toList();
    final sent =
        await ChildFriendlyContentGate.evaluateHubTopicsBatchSentiment(trimmed);
    if (!sent.ok) {
      developer.log(
        'DailyTopicsService: fallback topics failed Gemma sentiment → '
        '${sent.violations}',
        name: 'DailyTopicsService',
      );
      return [];
    }
    return trimmed;
  }
}
