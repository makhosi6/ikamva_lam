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

/// Extra demo quests (each topic has a full exercise matrix in dev seed).
const String kSeedQuestSchoolId = 'seed-quest-school';
const String kSeedQuestFamilyId = 'seed-quest-family';
const String kSeedQuestTravelId = 'seed-quest-travel';
const String kSeedQuestWeatherId = 'seed-quest-weather';

/// Template task ids used when cloning dev-seed rows onto another topic
/// ([TaskQueueService] fallback).
const List<String> kDevSeedFallbackTemplateTaskIds = [
  kSeedReorderId,
  kSeedMatchId,
  kSeedDialogueId,
  kSeedReadAloudId,
  kSeedPronunciationId,
  kSeedTaskId,
  kSeedTaskId2,
  kSeedTaskId3,
  kSeedTaskD2a,
  kSeedTaskD2b,
  kSeedTaskD3,
];

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
    '"left":["rice","bread","milk"],'
    '"right":["grain","slice","drink"],'
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

// --- School topic -----------------------------------------------------------

const String _schoolClozeA = '{'
    '"sentence":"We sit at a small ___ .",'
    '"answer":"table",'
    '"options":["table","chair","door","window"]'
    '}';

const String _schoolClozeB = '{'
    '"sentence":"I open my ___ to read.",'
    '"answer":"book",'
    '"options":["book","box","cup","hat"]'
    '}';

const String _schoolClozeC = '{'
    '"sentence":"The ___ helps us learn.",'
    '"answer":"teacher",'
    '"options":["teacher","student","cat","bird"]'
    '}';

const String _schoolReorder =
    '{"tokens":["class","I","like"],"correct_order":[1,0,2]}';

const String _schoolMatch = '{'
    '"left":["pen","ruler","bag"],'
    '"right":["write","measure","carry"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _schoolDialogue = '{'
    '"context":"The teacher gives you a new book.",'
    '"question":"What do you say?",'
    '"options":[{"id":"a","text":"Thank you."},{"id":"b","text":"Go away."}],'
    '"correct_index":0'
    '}';

const String _schoolRead = '{'
    '"display_text":"This is my school bag.",'
    '"instruction_en":"Say it clearly and slowly."'
    '}';

const String _schoolPronun = r'''{"question":"Which line stresses the word school?","options":["I walk to SCHOOL.","I WALK to school.","SCHOOL I walk to.","I walk school to."],"correct_index":0,"reference_line":"I walk to school."}''';

// --- Family topic -----------------------------------------------------------

const String _familyClozeA = '{'
    '"sentence":"We eat ___ at home.",'
    '"answer":"dinner",'
    '"options":["dinner","sleep","run","swim"]'
    '}';

const String _familyClozeB = '{'
    '"sentence":"My ___ cooks rice.",'
    '"answer":"mother",'
    '"options":["mother","shoe","tree","car"]'
    '}';

const String _familyClozeC = '{'
    '"sentence":"We ___ our family.",'
    '"answer":"love",'
    '"options":["love","kick","hide","sell"]'
    '}';

const String _familyReorder =
    '{"tokens":["home","I","like"],"correct_order":[1,0,2]}';

const String _familyMatch = '{'
    '"left":["sister","brother","baby"],'
    '"right":["girl","boy","small"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _familyDialogue = '{'
    '"context":"Grandma gives you a warm hug.",'
    '"question":"What do you say?",'
    '"options":[{"id":"a","text":"Thank you, Grandma."},{"id":"b","text":"Stop it."}],'
    '"correct_index":0'
    '}';

const String _familyRead = '{'
    '"display_text":"My family is kind to me.",'
    '"instruction_en":"Read with a warm, friendly tone."'
    '}';

const String _familyPronun = r'''{"question":"Which line stresses the word family?","options":["I love my FAMILY.","I LOVE my family.","FAMILY I love my.","I love family my."],"correct_index":0,"reference_line":"I love my family."}''';

// --- Travel topic -----------------------------------------------------------

const String _travelClozeA = '{'
    '"sentence":"We ___ the bus to town.",'
    '"answer":"take",'
    '"options":["take","eat","draw","sing"]'
    '}';

const String _travelClozeB = '{'
    '"sentence":"I buy a ___ at the station.",'
    '"answer":"ticket",'
    '"options":["ticket","cloud","sock","stone"]'
    '}';

const String _travelClozeC = '{'
    '"sentence":"The train is ___ .",'
    '"answer":"late",'
    '"options":["late","blue","round","sweet"]'
    '}';

const String _travelReorder =
    '{"tokens":["trip","a","nice"],"correct_order":[1,2,0]}';

const String _travelMatch = '{'
    '"left":["bus","train","map"],'
    '"right":["road","rails","paper"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _travelDialogue = '{'
    '"context":"You are at the bus stop with a friend.",'
    '"question":"The bus comes. What do you say?",'
    '"options":[{"id":"a","text":"Let us get on together."},{"id":"b","text":"Push me."}],'
    '"correct_index":0'
    '}';

const String _travelRead = '{'
    '"display_text":"Please wait in line for the bus.",'
    '"instruction_en":"Read like a polite sign at a stop."'
    '}';

const String _travelPronun = r'''{"question":"Which line stresses the word ticket?","options":["I need a TICKET.","I NEED a ticket.","TICKET I need a.","I need ticket a."],"correct_index":0,"reference_line":"I need a ticket."}''';

// --- Weather topic ----------------------------------------------------------

const String _weatherClozeA = '{'
    '"sentence":"Today is hot and ___ .",'
    '"answer":"sunny",'
    '"options":["sunny","metal","quiet","empty"]'
    '}';

const String _weatherClozeB = '{'
    '"sentence":"We wear a ___ when it rains.",'
    '"answer":"coat",'
    '"options":["coat","spoon","bell","rope"]'
    '}';

const String _weatherClozeC = '{'
    '"sentence":"The sky is ___ today.",'
    '"answer":"grey",'
    '"options":["grey","loud","sharp","fast"]'
    '}';

const String _weatherReorder =
    '{"tokens":["cold","it","is"],"correct_order":[2,1,0]}';

const String _weatherMatch = '{'
    '"left":["sun","rain","wind"],'
    '"right":["hot","wet","blow"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _weatherDialogue = '{'
    '"context":"Your friend forgot a hat on a cold day.",'
    '"question":"What do you say?",'
    '"options":[{"id":"a","text":"You can share my scarf."},{"id":"b","text":"I do not care."}],'
    '"correct_index":0'
    '}';

const String _weatherRead = '{'
    '"display_text":"It looks like rain this afternoon.",'
    '"instruction_en":"Read like a calm weather report."'
    '}';

const String _weatherPronun = r'''{"question":"Which line stresses the word rain?","options":["I hear RAIN.","I HEAR rain.","RAIN I hear.","I hear rain loud."],"correct_index":0,"reference_line":"I hear rain."}''';

void _insertTopicExerciseMatrix(
  Batch b,
  IkamvaDatabase db, {
  required String topic,
  required String questId,
  required DateTime questStart,
  required DateTime questEnd,
  required String reorderId,
  required String matchId,
  required String dialogueId,
  required String readId,
  required String pronunId,
  required String clozeAId,
  required String clozeBId,
  required String clozeCId,
  required String reorderJson,
  required String matchJson,
  required String dialogueJson,
  required String readJson,
  required String pronunJson,
  required String clozeAJson,
  required String clozeBJson,
  required String clozeCJson,
  required DateTime base,
}) {
  b.insert(
    db.quests,
    QuestsCompanion.insert(
      id: questId,
      topic: topic,
      level: 'A1',
      maxDifficultyStep: 3,
      sessionTimeLimitSec: const Value.absent(),
      maxTasks: const Value(16),
      startsAt: questStart,
      endsAt: questEnd,
      isActive: const Value(true),
    ),
  );
  var ms = 0;
  void task(
    String id,
    String type,
    String skill,
    int diff,
    String json,
  ) {
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: id,
        taskType: type,
        skillId: skill,
        difficulty: diff,
        topic: topic,
        payloadJson: json,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: base.add(Duration(milliseconds: ms++)),
      ),
    );
  }

  task(
    reorderId,
    TaskType.reorder.storageValue,
    SkillId.sentenceStructure.storageValue,
    1,
    reorderJson,
  );
  task(
    matchId,
    TaskType.match.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    matchJson,
  );
  task(
    dialogueId,
    TaskType.dialogueChoice.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    dialogueJson,
  );
  task(
    readId,
    TaskType.readAloud.storageValue,
    SkillId.readAloud.storageValue,
    1,
    readJson,
  );
  task(
    pronunId,
    TaskType.pronunciationIntonation.storageValue,
    SkillId.pronunciationIntonation.storageValue,
    1,
    pronunJson,
  );
  task(
    clozeAId,
    TaskType.cloze.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    clozeAJson,
  );
  task(
    clozeBId,
    TaskType.cloze.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    clozeBJson,
  );
  task(
    clozeCId,
    TaskType.cloze.storageValue,
    SkillId.vocabulary.storageValue,
    2,
    clozeCJson,
  );
}

/// Inserts seed profile, quest, and a **full A1 exercise matrix** per topic
/// when the DB has no learners (TASKS §2.8, mixed task types for demos).
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
        maxTasks: const Value(24),
        startsAt: now,
        endsAt: questEnd,
        isActive: const Value(true),
      ),
    );

    var ms = 0;
    void foodTask(
      String id,
      String type,
      String skill,
      int diff,
      String json,
    ) {
      b.insert(
        db.taskRecords,
        TaskRecordsCompanion.insert(
          id: id,
          taskType: type,
          skillId: skill,
          difficulty: diff,
          topic: 'food',
          payloadJson: json,
          source: TaskSource.devSeedOnly.storageValue,
          createdAt: now.add(Duration(milliseconds: ms++)),
        ),
      );
    }

    // Non-cloze first so a capped session still includes every task type.
    foodTask(
      kSeedReorderId,
      TaskType.reorder.storageValue,
      SkillId.sentenceStructure.storageValue,
      1,
      kSeedReorderPayloadJson,
    );
    foodTask(
      kSeedMatchId,
      TaskType.match.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedMatchPayloadJson,
    );
    foodTask(
      kSeedDialogueId,
      TaskType.dialogueChoice.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedDialoguePayloadJson,
    );
    foodTask(
      kSeedReadAloudId,
      TaskType.readAloud.storageValue,
      SkillId.readAloud.storageValue,
      1,
      kSeedReadAloudPayloadJson,
    );
    foodTask(
      kSeedPronunciationId,
      TaskType.pronunciationIntonation.storageValue,
      SkillId.pronunciationIntonation.storageValue,
      1,
      kSeedPronunciationPayloadJson,
    );
    foodTask(
      kSeedTaskId,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedClozePayloadJson,
    );
    foodTask(
      kSeedTaskId2,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedCloze2PayloadJson,
    );
    foodTask(
      kSeedTaskId3,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedCloze3PayloadJson,
    );
    foodTask(
      kSeedTaskD2a,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      2,
      kSeedClozeD2aPayloadJson,
    );
    foodTask(
      kSeedTaskD2b,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      2,
      kSeedClozeD2bPayloadJson,
    );
    foodTask(
      kSeedTaskD3,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      3,
      kSeedClozeD3PayloadJson,
    );
  });
}

/// Adds non-cloze demo tasks for **legacy** DBs created before mixed-type
/// [ensureDevSeed] (TASKS §10.x).
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

/// Idempotent: extra **topics + quests**, each with all six task kinds.
Future<void> ensureMultiTopicQuestSeed(IkamvaDatabase db) async {
  final hit = await (db.select(db.quests)
        ..where((q) => q.id.equals(kSeedQuestSchoolId)))
      .getSingleOrNull();
  if (hit != null) return;

  final now = DateTime.now().toUtc();
  final questEnd = now.add(const Duration(days: 30));

  await db.batch((b) {
    _insertTopicExerciseMatrix(
      b,
      db,
      topic: 'school',
      questId: kSeedQuestSchoolId,
      questStart: now,
      questEnd: questEnd,
      reorderId: 'seed-school-reorder',
      matchId: 'seed-school-match',
      dialogueId: 'seed-school-dialogue',
      readId: 'seed-school-read',
      pronunId: 'seed-school-pronun',
      clozeAId: 'seed-school-cloze-a',
      clozeBId: 'seed-school-cloze-b',
      clozeCId: 'seed-school-cloze-c',
      reorderJson: _schoolReorder,
      matchJson: _schoolMatch,
      dialogueJson: _schoolDialogue,
      readJson: _schoolRead,
      pronunJson: _schoolPronun,
      clozeAJson: _schoolClozeA,
      clozeBJson: _schoolClozeB,
      clozeCJson: _schoolClozeC,
      base: now.add(const Duration(seconds: 1)),
    );
    _insertTopicExerciseMatrix(
      b,
      db,
      topic: 'family',
      questId: kSeedQuestFamilyId,
      questStart: now,
      questEnd: questEnd,
      reorderId: 'seed-family-reorder',
      matchId: 'seed-family-match',
      dialogueId: 'seed-family-dialogue',
      readId: 'seed-family-read',
      pronunId: 'seed-family-pronun',
      clozeAId: 'seed-family-cloze-a',
      clozeBId: 'seed-family-cloze-b',
      clozeCId: 'seed-family-cloze-c',
      reorderJson: _familyReorder,
      matchJson: _familyMatch,
      dialogueJson: _familyDialogue,
      readJson: _familyRead,
      pronunJson: _familyPronun,
      clozeAJson: _familyClozeA,
      clozeBJson: _familyClozeB,
      clozeCJson: _familyClozeC,
      base: now.add(const Duration(seconds: 2)),
    );
    _insertTopicExerciseMatrix(
      b,
      db,
      topic: 'travel',
      questId: kSeedQuestTravelId,
      questStart: now,
      questEnd: questEnd,
      reorderId: 'seed-travel-reorder',
      matchId: 'seed-travel-match',
      dialogueId: 'seed-travel-dialogue',
      readId: 'seed-travel-read',
      pronunId: 'seed-travel-pronun',
      clozeAId: 'seed-travel-cloze-a',
      clozeBId: 'seed-travel-cloze-b',
      clozeCId: 'seed-travel-cloze-c',
      reorderJson: _travelReorder,
      matchJson: _travelMatch,
      dialogueJson: _travelDialogue,
      readJson: _travelRead,
      pronunJson: _travelPronun,
      clozeAJson: _travelClozeA,
      clozeBJson: _travelClozeB,
      clozeCJson: _travelClozeC,
      base: now.add(const Duration(seconds: 3)),
    );
    _insertTopicExerciseMatrix(
      b,
      db,
      topic: 'weather',
      questId: kSeedQuestWeatherId,
      questStart: now,
      questEnd: questEnd,
      reorderId: 'seed-weather-reorder',
      matchId: 'seed-weather-match',
      dialogueId: 'seed-weather-dialogue',
      readId: 'seed-weather-read',
      pronunId: 'seed-weather-pronun',
      clozeAId: 'seed-weather-cloze-a',
      clozeBId: 'seed-weather-cloze-b',
      clozeCId: 'seed-weather-cloze-c',
      reorderJson: _weatherReorder,
      matchJson: _weatherMatch,
      dialogueJson: _weatherDialogue,
      readJson: _weatherRead,
      pronunJson: _weatherPronun,
      clozeAJson: _weatherClozeA,
      clozeBJson: _weatherClozeB,
      clozeCJson: _weatherClozeC,
      base: now.add(const Duration(seconds: 4)),
    );
  });
}
