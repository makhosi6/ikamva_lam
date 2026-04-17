import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// SQLite persistence for per-skill difficulty (TASKS §5.4).
class DifficultyStateRepository {
  DifficultyStateRepository(this._db);

  final IkamvaDatabase _db;

  /// [questKey] use `''` for practice / global; otherwise the quest id.
  Future<SkillDifficultyState?> getRow(
    String learnerId,
    String skillId,
    String questKey,
  ) {
    return (_db.select(_db.skillDifficultyStates)
          ..where(
            (s) =>
                s.learnerId.equals(learnerId) &
                s.skillId.equals(skillId) &
                s.questId.equals(questKey),
          ))
        .getSingleOrNull();
  }

  Future<void> upsert({
    required String learnerId,
    required String skillId,
    required String questKey,
    required int step,
    required bool hintFirstMode,
    DateTime? updatedAt,
  }) async {
    final at = updatedAt ?? DateTime.now().toUtc();
    await _db.into(_db.skillDifficultyStates).insertOnConflictUpdate(
          SkillDifficultyStatesCompanion.insert(
            learnerId: learnerId,
            skillId: skillId,
            questId: Value(questKey),
            step: Value(step),
            hintFirstMode: Value(hintFirstMode),
            updatedAt: at,
          ),
        );
  }
}
