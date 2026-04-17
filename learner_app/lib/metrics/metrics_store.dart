import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight on-device judging counters (TASKS §15.3).
abstract final class MetricsStore {
  static const _k = 'ikamva_metrics_v1';

  static Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) {
      return {
        'sessions_completed': 0,
        'attempts_total': 0,
        'hints_total': 0,
        'correct_total': 0,
      };
    }
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) return m;
    } on Object {
      // ignore
    }
    return {'sessions_completed': 0};
  }

  static Future<void> recordSession({
    required int attempts,
    required int hints,
    required int correct,
  }) async {
    final p = await SharedPreferences.getInstance();
    final cur = await load();
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return 0;
    }

    cur['sessions_completed'] = asInt(cur['sessions_completed']) + 1;
    cur['attempts_total'] = asInt(cur['attempts_total']) + attempts;
    cur['hints_total'] = asInt(cur['hints_total']) + hints;
    cur['correct_total'] = asInt(cur['correct_total']) + correct;
    await p.setString(_k, jsonEncode(cur));
  }
}
