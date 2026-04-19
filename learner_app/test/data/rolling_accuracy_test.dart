import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/data/attempt_repository.dart';
import 'package:ikamva_lam/db/app_database.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/domain/skill_id.dart';
import 'package:ikamva_lam/domain/task_source.dart';
import 'package:ikamva_lam/domain/task_type.dart';

void main() {
  test('rollingAccuracyOverallBefore excludes session attempts', () async {
    final db = openMemoryDatabase();
    await ensureDevSeed(db);
    final t0 = DateTime.utc(2026, 2, 1, 10);
    final t1 = DateTime.utc(2026, 2, 1, 11);
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-a',
            questId: Value(kSeedQuestId),
            startedAt: t1,
          ),
        );
    final attempts = AttemptRepository(db);
    await attempts.insert(
      AttemptsCompanion.insert(
        id: 'a1',
        taskId: kSeedTaskId,
        sessionId: 'sess-a',
        learnerAnswerJson: '{}',
        correct: true,
        usedHint: false,
        timestamp: t0,
      ),
    );
    await attempts.insert(
      AttemptsCompanion.insert(
        id: 'a2',
        taskId: kSeedTaskId2,
        sessionId: 'sess-a',
        learnerAnswerJson: '{}',
        correct: false,
        usedHint: false,
        timestamp: t1.add(const Duration(seconds: 1)),
      ),
    );

    final before = await attempts.rollingAccuracyOverallBefore(
      beforeExclusive: t1,
    );
    expect(before, 1.0);

    final skillRoll = await attempts.rollingAccuracyForSkill(
      SkillId.vocabulary.storageValue,
    );
    expect(skillRoll, closeTo(0.5, 1e-9));
    await db.close();
  });

  test('rollingAccuracyForSkill respects window size', () async {
    final db = openMemoryDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await db.into(db.learnerProfiles).insert(
          LearnerProfilesCompanion.insert(
            id: 'l1',
            displayName: 'T',
            createdAt: now,
          ),
        );
    await db.into(db.taskRecords).insert(
          TaskRecordsCompanion.insert(
            id: 'tk1',
            taskType: TaskType.cloze.storageValue,
            skillId: SkillId.vocabulary.storageValue,
            difficulty: 1,
            topic: 'x',
            payloadJson: '{"sentence":"I ___ .","answer":"a","options":["a","b","c","d"]}',
            source: TaskSource.devSeedOnly.storageValue,
            createdAt: now,
          ),
        );
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(id: 's1', startedAt: now),
        );
    final attempts = AttemptRepository(db);
    for (var i = 0; i < 12; i++) {
      await attempts.insert(
        AttemptsCompanion.insert(
          id: 'att-$i',
          taskId: 'tk1',
          sessionId: 's1',
          learnerAnswerJson: '{}',
          correct: i.isEven,
          usedHint: false,
          timestamp: now.add(Duration(seconds: i)),
        ),
      );
    }
    final r = await attempts.rollingAccuracyForSkill(
      SkillId.vocabulary.storageValue,
      windowSize: 10,
    );
    expect(r, 0.5);
    await db.close();
  });
}
