import 'package:drift/drift.dart';

import '../domain/skill_id.dart';
import '../domain/task_source.dart';
import '../domain/task_type.dart';
import 'app_database.dart';

/// Stable dev IDs for UI work without AI (TASKS §2.8).
const String kSeedLearnerId = 'seed-learner-1';
const String kSeedQuestId = 'seed-quest-1';
const String kSeedTaskId = 'seed-task-cloze-1';

/// Sample cloze payload (Phase 3 will add typed models + validation).
const String kSeedClozePayloadJson = '{'
    '"sentence":"I like to ___ fruit.",'
    '"answer":"eat",'
    '"options":["eat","eats","eating","ate"]'
    '}';

/// Inserts seed profile, quest, and one cached task when the DB has no learners.
Future<void> ensureDevSeed(IkamvaDatabase db) async {
  final count = await db.select(db.learnerProfiles).get();
  if (count.isNotEmpty) return;

  final now = DateTime.now().toUtc();
  final questEnd = now.add(const Duration(days: 30));

  await db.batch((b) {
    b.insert(
      db.learnerProfiles,
      LearnerProfilesCompanion.insert(
        id: kSeedLearnerId,
        displayName: 'Demo learner',
        homeLanguageCode: const Value('xh'),
        pairedTeacherCode: const Value('TEACH-DEMO'),
        createdAt: now,
      ),
    );
    b.insert(
      db.quests,
      QuestsCompanion.insert(
        id: kSeedQuestId,
        topic: 'food',
        level: 'A1',
        maxDifficultyStep: 3,
        sessionTimeLimitSec: const Value.absent(),
        maxTasks: const Value(10),
        startsAt: now,
        endsAt: questEnd,
        isActive: const Value(true),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedTaskId,
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedClozePayloadJson,
        source: TaskSource.cached.storageValue,
        createdAt: now,
      ),
    );
  });
}
