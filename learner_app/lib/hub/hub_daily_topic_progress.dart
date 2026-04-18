import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'daily_quest_ids.dart';

/// Tracks which hub topics the learner finished a session for today (local day).
abstract final class HubDailyTopicProgress {
  static const _key = 'hub_daily_topic_done_v1';

  static Future<Set<String>> completedForDay(String dayKey) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['day'] != dayKey) return {};
      final list = j['done'];
      if (list is! List) return {};
      return {
        for (final e in list)
          DailyQuestIds.normalizeTopicToken(e.toString()),
      };
    } on Object {
      return {};
    }
  }

  static Future<void> markCompleted(String dayKey, String topic) async {
    final t = DailyQuestIds.normalizeTopicToken(topic);
    if (t.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final done = await completedForDay(dayKey);
    done.add(t);
    final list = done.toList()..sort();
    await p.setString(
      _key,
      jsonEncode({'day': dayKey, 'done': list}),
    );
  }
}
