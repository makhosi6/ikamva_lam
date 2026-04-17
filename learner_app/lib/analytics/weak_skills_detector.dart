import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Row for teacher / export (TASKS §11.1).
class WeakSkillRow {
  WeakSkillRow({
    required this.skillId,
    required this.attempts,
    required this.correct,
  });

  final String skillId;
  final int attempts;
  final int correct;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
}

/// Flags skills below threshold over recent attempts (TASKS §11.1).
class WeakSkillsDetector {
  WeakSkillsDetector(this._db);

  final IkamvaDatabase _db;

  static const double weakThreshold = 0.55;

  Future<List<WeakSkillRow>> detect({int maxAttempts = 80}) async {
    final attempts = await (_db.select(_db.attempts)
          ..orderBy([(a) => OrderingTerm(expression: a.timestamp, mode: OrderingMode.desc)])
          ..limit(maxAttempts))
        .get();
    if (attempts.isEmpty) return [];
    final tasks = await _db.select(_db.taskRecords).get();
    final byId = {for (final t in tasks) t.id: t};
    final agg = <String, _Agg>{};
    for (final a in attempts) {
      final task = byId[a.taskId];
      if (task == null) continue;
      final g = agg.putIfAbsent(task.skillId, () => _Agg());
      g.n++;
      if (a.correct) g.ok++;
    }
    final out = <WeakSkillRow>[];
    for (final e in agg.entries) {
      if (e.value.n < 3) continue;
      final row = WeakSkillRow(
        skillId: e.key,
        attempts: e.value.n,
        correct: e.value.ok,
      );
      if (row.accuracy < weakThreshold) {
        out.add(row);
      }
    }
    out.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return out;
  }
}

class _Agg {
  _Agg();
  int n = 0;
  int ok = 0;
}
