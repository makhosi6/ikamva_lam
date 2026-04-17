import 'dart:convert';

import '../db/app_database.dart';
import '../db/seed.dart';
import 'error_clustering.dart';
import 'weak_skills_detector.dart';

/// Summary-only JSON for sync / judges (TASKS §11.4).
class ExportSummaryService {
  ExportSummaryService(this._db);

  final IkamvaDatabase _db;

  Future<String> buildSummaryJson() async {
    final sessions = await _db.select(_db.sessions).get();
    final attempts = await _db.select(_db.attempts).get();
    final weak = await WeakSkillsDetector(_db).detect();
    final top3 = weak.take(3).map((w) {
      return {
        'skill': w.skillId,
        'accuracy': w.accuracy,
        'attempts': w.attempts,
        'cluster': ErrorClustering.bucketForSkill(w.skillId),
      };
    }).toList();
    final last = sessions.isEmpty
        ? null
        : sessions.reduce((a, b) => a.startedAt.isAfter(b.startedAt) ? a : b);
    return jsonEncode({
      'learner_id': kSeedLearnerId,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'sessions_total': sessions.length,
      'attempts_total': attempts.length,
      'top_weak_skills': top3,
      'last_session': last == null
          ? null
          : {
              'id': last.id,
              'tasks_completed': last.tasksCompleted,
              'accuracy': last.accuracy,
              'hint_rate': last.hintRate,
            },
    });
  }
}
