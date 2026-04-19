import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/analytics/insight_job.dart';
import 'package:ikamva_lam/data/attempt_repository.dart';
import 'package:ikamva_lam/data/insight_card_repository.dart';
import 'package:ikamva_lam/data/session_repository.dart';
import 'package:ikamva_lam/db/app_database.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/llm/llm_service.dart';
import 'package:ikamva_lam/safety/child_friendly_content_gate.dart';
import 'package:ikamva_lam/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IkamvaDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.load();
    LlmService.instance.invalidateCachedEngine();
    await LlmService.instance.configure(settings);

    db = openMemoryDatabase();
    await ensureDevSeed(db);
  });

  tearDown(() async {
    LlmService.instance.invalidateCachedEngine();
    await db.close();
  });

  test(
    'InsightJob inserts insight card after weak-skill signal when gate passes',
    () async {
      const uuid = Uuid();
      final sessionId = 'sess-${uuid.v4()}';
      await SessionRepository(db).insert(
        SessionsCompanion.insert(
          id: sessionId,
          questId: const Value(kSeedQuestId),
          startedAt: DateTime.now().toUtc(),
        ),
      );
      final attempts = AttemptRepository(db);
      for (var i = 0; i < 4; i++) {
        await attempts.insert(
          AttemptsCompanion.insert(
            id: 'att-$i-${uuid.v4()}',
            taskId: kSeedTaskId,
            sessionId: sessionId,
            learnerAnswerJson: '{"choice":"wrong"}',
            correct: false,
            usedHint: false,
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }

      await InsightJob.runAfterSession(db, sessionId);

      final cards = await InsightCardRepository(db).listForLearner(kSeedLearnerId);
      expect(cards, isNotEmpty);
      expect(cards.first.issue, isNotEmpty);
    },
  );

  test('insight-shaped content fails gate when issue contains blocked token',
      () async {
    final v = await ChildFriendlyContentGate.evaluateJsonValue({
      'issue': 'bad shit here',
      'pattern': 'ok pattern',
      'recommendation': 'ok rec',
    });
    expect(v.ok, isFalse);
  });
}
