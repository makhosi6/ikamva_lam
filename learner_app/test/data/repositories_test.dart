import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/data/attempt_repository.dart';
import 'package:ikamva_lam/data/learner_profile_repository.dart';
import 'package:ikamva_lam/data/quest_repository.dart';
import 'package:ikamva_lam/data/session_repository.dart';
import 'package:ikamva_lam/data/sync_outbox_repository.dart';
import 'package:ikamva_lam/data/task_record_repository.dart';
import 'package:ikamva_lam/db/app_database.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/domain/skill_id.dart';
import 'package:ikamva_lam/domain/task_type.dart';
import 'package:uuid/uuid.dart';

void main() {
  late IkamvaDatabase db;

  setUp(() async {
    db = openMemoryDatabase();
    await ensureDevSeed(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LearnerProfileRepository', () {
    test('getById returns seed learner', () async {
      final repo = LearnerProfileRepository(db);
      final row = await repo.getById(kSeedLearnerId);
      expect(row, isNotNull);
      expect(row!.displayName, 'Demo learner');
      expect(row.homeLanguageCode, 'xh');
    });

    test('upsert updates display name', () async {
      final repo = LearnerProfileRepository(db);
      await repo.upsert(
        LearnerProfilesCompanion(
          id: const Value(kSeedLearnerId),
          displayName: const Value('Updated'),
          createdAt: Value(DateTime.now().toUtc()),
        ),
      );
      final row = await repo.getById(kSeedLearnerId);
      expect(row!.displayName, 'Updated');
    });
  });

  group('QuestRepository', () {
    test('getById returns seed quest', () async {
      final repo = QuestRepository(db);
      final q = await repo.getById(kSeedQuestId);
      expect(q, isNotNull);
      expect(q!.topic, 'food');
      expect(q.maxTasks, 24);
    });

    test('listActive includes seed quest', () async {
      final repo = QuestRepository(db);
      final list = await repo.listActive();
      expect(list.map((e) => e.id), contains(kSeedQuestId));
    });
  });

  group('TaskRecordRepository', () {
    test('listByTopic returns seed cloze', () async {
      final repo = TaskRecordRepository(db);
      final tasks = await repo.listByTopic('food');
      expect(tasks, isNotEmpty);
      expect(tasks.map((e) => e.id), contains(kSeedTaskId));
      final cloze = tasks.firstWhere((t) => t.id == kSeedTaskId);
      expect(cloze.taskType, TaskType.cloze.storageValue);
      expect(cloze.skillId, SkillId.vocabulary.storageValue);
    });
  });

  group('SessionRepository', () {
    test('insert and update session', () async {
      const uuid = Uuid();
      final sid = uuid.v4();
      final repo = SessionRepository(db);
      final started = DateTime.now().toUtc();
      await repo.insert(
        SessionsCompanion.insert(
          id: sid,
          questId: const Value(kSeedQuestId),
          startedAt: started,
        ),
      );
      var s = await repo.getById(sid);
      expect(s!.tasksCompleted, 0);

      await repo.update(
        sid,
        SessionsCompanion(
          endedAt: Value(DateTime.now().toUtc()),
          tasksCompleted: const Value(3),
          accuracy: const Value(0.66),
          hintRate: const Value(0.1),
        ),
      );
      s = await repo.getById(sid);
      expect(s!.tasksCompleted, 3);
      expect(s.accuracy, closeTo(0.66, 0.001));
    });
  });

  group('AttemptRepository', () {
    test('insert and listForSession', () async {
      const uuid = Uuid();
      final sessionId = uuid.v4();
      final attemptId = uuid.v4();
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: sessionId,
              questId: const Value(kSeedQuestId),
              startedAt: DateTime.now().toUtc(),
            ),
          );

      final repo = AttemptRepository(db);
      await repo.insert(
        AttemptsCompanion.insert(
          id: attemptId,
          taskId: kSeedTaskId,
          sessionId: sessionId,
          learnerAnswerJson: '{"choice":"eat"}',
          correct: true,
          usedHint: false,
          timestamp: DateTime.now().toUtc(),
        ),
      );

      final list = await repo.listForSession(sessionId);
      expect(list, hasLength(1));
      expect(list.single.correct, isTrue);
    });
  });

  group('SyncOutboxRepository', () {
    test('insert and getById', () async {
      const uuid = Uuid();
      final id = uuid.v4();
      final repo = SyncOutboxRepository(db);
      await repo.insert(
        SyncOutboxEntriesCompanion.insert(
          id: id,
          payloadJson: '{"summary":true}',
          entityType: 'session_summary',
        ),
      );
      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.retryCount, 0);
      expect(row.entityType, 'session_summary');
    });
  });

  group('ensureDevSeed', () {
    test('is idempotent', () async {
      await ensureDevSeed(db);
      await ensureDevSeed(db);
      final profiles = await db.select(db.learnerProfiles).get();
      expect(profiles, hasLength(1));
    });
  });
}
