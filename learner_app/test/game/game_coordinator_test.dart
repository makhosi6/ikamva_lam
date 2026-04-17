import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/data/quest_repository.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/game/game_coordinator.dart';

void main() {
  group('GameCoordinator', () {
    test('loadTasksForQuest returns seed task for seed quest topic', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = await QuestRepository(db).getById(kSeedQuestId);
      expect(quest, isNotNull);

      final coord = GameCoordinator(db);
      final tasks = await coord.loadTasksForQuest(quest!);
      expect(tasks, hasLength(3));
      expect(tasks.map((t) => t.id).toList(), [
        kSeedTaskId,
        kSeedTaskId2,
        kSeedTaskId3,
      ]);
      expect(tasks.first.topic, quest.topic);
      await db.close();
    });

    test('loadTasksForPractice respects topic and maxTasks', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
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
  });
}
