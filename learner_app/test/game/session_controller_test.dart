import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/data/quest_repository.dart';
import 'package:ikamva_lam/data/session_repository.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/game/session_controller.dart';

void main() {
  group('SessionController', () {
    test('startForQuest, addAttempt attaches sessionId, endSession stats', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = await QuestRepository(db).getById(kSeedQuestId);
      expect(quest, isNotNull);

      final ctrl = SessionController(db);
      final session = await ctrl.startForQuest(quest!);
      expect(session.questId, quest.id);
      expect(session.endedAt, isNull);

      ctrl.acquireTaskSlot();
      final att = await ctrl.addAttempt(
        taskId: kSeedTaskId,
        learnerAnswerJson: '{"choice":"eat"}',
        correct: true,
        usedHint: false,
      );
      expect(att.sessionId, session.id);

      final ended = await ctrl.endSession();
      expect(ended.endedAt, isNotNull);
      expect(ended.tasksCompleted, 1);
      expect(ended.accuracy, 1.0);
      expect(ended.hintRate, 0.0);
      expect(ctrl.activeSessionId, isNull);

      await db.close();
    });

    test('maxTasks from quest blocks extra acquireTaskSlot', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = (await QuestRepository(db).getById(kSeedQuestId))!;

      final capped = quest.copyWith(maxTasks: const Value(1));
      final ctrl = SessionController(db);
      await ctrl.startForQuest(capped);

      ctrl.acquireTaskSlot();
      expect(
        () => ctrl.acquireTaskSlot(),
        throwsA(isA<SessionLimitExceeded>().having((e) => e.reason, 'reason', 'max_tasks')),
      );

      await ctrl.endSession();
      await db.close();
    });

    test('practice time limit enforced via clock', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);

      var t = DateTime.utc(2026, 1, 1, 12);
      final ctrl = SessionController(db, clock: () => t);
      await ctrl.startPractice(timeLimitSec: 60);

      ctrl.acquireTaskSlot();
      t = t.add(const Duration(seconds: 61));

      expect(
        () => ctrl.acquireTaskSlot(),
        throwsA(isA<SessionLimitExceeded>().having((e) => e.reason, 'reason', 'time_limit')),
      );

      await ctrl.endSession();
      await db.close();
    });

    test('resumeOpenQuestSession restores reserved slots', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = (await QuestRepository(db).getById(kSeedQuestId))!;

      final first = SessionController(db);
      final session = await first.startForQuest(quest);
      first.acquireTaskSlot();
      first.acquireTaskSlot();
      expect(first.reservedTaskSlotCount, 2);

      final second = SessionController(db);
      final loaded = await SessionRepository(db).getById(session.id);
      await second.resumeOpenQuestSession(
        session: loaded!,
        quest: quest,
        tasksAlreadyReserved: 2,
      );
      expect(second.reservedTaskSlotCount, 2);
      expect(second.activeSessionId, session.id);

      await second.endSession();
      await db.close();
    });

    test('cannot start a new session while one is active', () async {
      final db = openMemoryDatabase();
      await ensureDevSeed(db);
      final quest = (await QuestRepository(db).getById(kSeedQuestId))!;

      final ctrl = SessionController(db);
      await ctrl.startForQuest(quest);
      expect(() => ctrl.startForQuest(quest), throwsStateError);

      await ctrl.endSession();
      await db.close();
    });
  });
}
