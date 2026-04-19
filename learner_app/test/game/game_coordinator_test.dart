import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/config/learner_content_policy.dart';
import 'package:ikamva_lam/data/quest_repository.dart';
import 'package:ikamva_lam/db/app_database.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/domain/skill_id.dart';
import 'package:ikamva_lam/domain/task_source.dart';
import 'package:ikamva_lam/domain/task_type.dart';
import 'package:ikamva_lam/game/game_coordinator.dart';

void main() {
  group('GameCoordinator', () {
    test('loadTasksForQuest returns seed task for seed quest topic', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      await ensureMultiTopicQuestSeed(db);
      final quest = await QuestRepository(db).getById(kSeedQuestId);
      expect(quest, isNotNull);

      final coord = GameCoordinator(db);
      final tasks = await coord.loadTasksForQuest(quest!);
      expect(tasks, hasLength(11));
      final types = tasks.map((t) => TaskType.parse(t.taskType)).toSet();
      expect(types, TaskType.values.toSet());
      expect(tasks.first.topic, quest.topic);
      await db.close();
    });

    test('multi-topic seed quest includes every exercise type', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      await ensureMultiTopicQuestSeed(db);
      final quest = await QuestRepository(db).getById(kSeedQuestSchoolId);
      expect(quest, isNotNull);
      final tasks = await GameCoordinator(db).loadTasksForQuest(quest!);
      final types = tasks.map((t) => TaskType.parse(t.taskType)).toSet();
      expect(types, TaskType.values.toSet());
      await db.close();
    });

    test('dev seed exposes at least ten distinct quest topics', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      await ensureMultiTopicQuestSeed(db);
      final quests = await QuestRepository(db).listAll();
      final topics = quests.map((q) => q.topic).toSet();
      expect(topics.length, greaterThanOrEqualTo(10));
      await db.close();
    });

    test('loadTasksForQuest respects maxDifficultyInclusive', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = (await QuestRepository(db).getById(kSeedQuestId))!;
      final coord = GameCoordinator(db);
      final easy = await coord.loadTasksForQuest(
        quest,
        maxDifficultyInclusive: 1,
      );
      expect(easy, hasLength(8));
      final mid = await coord.loadTasksForQuest(
        quest,
        maxDifficultyInclusive: 2,
      );
      expect(mid, hasLength(10));
      await db.close();
    });

    test('loadTasksForPractice respects topic and maxTasks', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      await ensureMultiTopicQuestSeed(db);
      final coord = GameCoordinator(db);
      final tasks = await coord.loadTasksForPractice(
        const PracticeTaskConfig(topic: 'food', maxTasks: 1),
      );
      expect(tasks, hasLength(1));
      await db.close();
    });

    test('watchTasksForQuest first emission matches load', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = await QuestRepository(db).getById(kSeedQuestId);
      expect(quest, isNotNull);
      final q = quest!;
      final coord = GameCoordinator(db);
      final watched = await coord.watchTasksForQuest(q).first;
      final loaded = await coord.loadTasksForQuest(q);
      expect(watched, loaded);
      await db.close();
    });

    test('strict learner policy lists only AI-sourced tasks', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = (await QuestRepository(db).getById(kSeedQuestId))!;
      await db.into(db.taskRecords).insert(
            TaskRecordsCompanion.insert(
              id: 'ai-only-strict-1',
              taskType: TaskType.cloze.storageValue,
              skillId: SkillId.vocabulary.storageValue,
              difficulty: 1,
              topic: quest.topic,
              payloadJson: kSeedClozePayloadJson,
              source: TaskSource.generated.storageValue,
              createdAt: DateTime.now().toUtc(),
            ),
          );
      LearnerContentPolicy.debugAllowDevSeedOverride = false;
      addTearDown(() => LearnerContentPolicy.debugAllowDevSeedOverride = null);

      final coord = GameCoordinator(db);
      final tasks = await coord.loadTasksForQuest(quest);
      expect(tasks, hasLength(1));
      expect(tasks.single.id, 'ai-only-strict-1');
      await db.close();
    });
  });
}
