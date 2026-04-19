import 'package:drift/drift.dart';

import '../domain/skill_id.dart';
import '../domain/task_source.dart';
import '../domain/task_type.dart';
import 'app_database.dart';

/// Stable dev IDs for UI work without AI (TASKS §2.8).
const String kSeedLearnerId = 'seed-learner-1';
const String kSeedQuestId = 'seed-quest-1';
const String kSeedTaskId = 'seed-task-cloze-1';
const String kSeedTaskId2 = 'seed-task-cloze-2';
const String kSeedTaskId3 = 'seed-task-cloze-3';
const String kSeedTaskD2a = 'seed-task-cloze-d2-a';
const String kSeedTaskD2b = 'seed-task-cloze-d2-b';
const String kSeedTaskD3 = 'seed-task-cloze-d3';
const String kSeedReorderId = 'seed-task-reorder-1';
const String kSeedMatchId = 'seed-task-match-1';
const String kSeedDialogueId = 'seed-task-dialogue-1';
const String kSeedReadAloudId = 'seed-task-read-aloud-1';
const String kSeedPronunciationId = 'seed-task-pronunciation-1';

/// Sample cloze payload (Phase 3 will add typed models + validation).
const String kSeedClozePayloadJson = '{'
    '"sentence":"I like to ___ fruit.",'
    '"answer":"eat",'
    '"options":["eat","eats","eating","ate"]'
    '}';

const String kSeedCloze2PayloadJson = '{'
    '"sentence":"We drink ___ in the morning.",'
    '"answer":"water",'
    '"options":["water","milk","tea","juice"]'
    '}';

const String kSeedCloze3PayloadJson = '{'
    '"sentence":"This is a small ___ .",'
    '"answer":"apple",'
    '"options":["apple","banana","bread","plate"]'
    '}';

const String kSeedClozeD2aPayloadJson = '{'
    '"sentence":"They ___ rice for dinner.",'
    '"answer":"cook",'
    '"options":["cook","cooks","cooking","cooked"]'
    '}';

const String kSeedClozeD2bPayloadJson = '{'
    '"sentence":"She ___ a red apple.",'
    '"answer":"has",'
    '"options":["has","have","having","had"]'
    '}';

const String kSeedClozeD3PayloadJson = '{'
    '"sentence":"We need ___ bread from the shop.",'
    '"answer":"more",'
    '"options":["more","many","much","most"]'
    '}';

const String kSeedReorderPayloadJson =
    '{"tokens":["like","I","apples"],"correct_order":[1,0,2]}';

const String kSeedMatchPayloadJson = '{'
    '"left":["cat","dog","bird"],'
    '"right":["meow","bark","tweet"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String kSeedDialoguePayloadJson = '{'
    '"context":"Sam is hungry at the table.",'
    '"question":"What should Sam say?",'
    '"options":[{"id":"a","text":"I want some food."},{"id":"b","text":"I want a hat."}],'
    '"correct_index":0'
    '}';

const String kSeedReadAloudPayloadJson = '{'
    '"display_text":"I would like some water, please.",'
    '"instruction_en":"Read it politely, like at the school lunch line."'
    '}';

const String kSeedPronunciationPayloadJson = r'''{"question":"Which line puts the strongest stress on the food word?","options":["I like SOME rice.","I LIKE some rice.","I like some RICE.","LIKE I some rice."],"correct_index":2,"reference_line":"I like some rice."}''';

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
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now,
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedTaskId2,
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedCloze2PayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 1)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedTaskId3,
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedCloze3PayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 2)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedTaskD2a,
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 2,
        topic: 'food',
        payloadJson: kSeedClozeD2aPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 3)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedTaskD2b,
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 2,
        topic: 'food',
        payloadJson: kSeedClozeD2bPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 4)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedTaskD3,
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 3,
        topic: 'food',
        payloadJson: kSeedClozeD3PayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 5)),
      ),
    );
  });
}

/// Adds non-cloze demo tasks for mixed-type sessions (TASKS §10.x).
Future<void> ensureExtraSeedTaskTypes(IkamvaDatabase db) async {
  final existing = await (db.select(db.taskRecords)
        ..where((t) => t.id.equals(kSeedReorderId)))
      .getSingleOrNull();
  if (existing != null) return;
  final now = DateTime.now().toUtc();
  await db.batch((b) {
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedReorderId,
        taskType: TaskType.reorder.storageValue,
        skillId: SkillId.sentenceStructure.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedReorderPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now,
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedMatchId,
        taskType: TaskType.match.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedMatchPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 1)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedDialogueId,
        taskType: TaskType.dialogueChoice.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedDialoguePayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 2)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedReadAloudId,
        taskType: TaskType.readAloud.storageValue,
        skillId: SkillId.readAloud.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedReadAloudPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 3)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedPronunciationId,
        taskType: TaskType.pronunciationIntonation.storageValue,
        skillId: SkillId.pronunciationIntonation.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedPronunciationPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 4)),
      ),
    );
  });
}
