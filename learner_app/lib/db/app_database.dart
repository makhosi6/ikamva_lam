import 'package:drift/drift.dart';

import 'drift_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LearnerProfiles,
    Quests,
    TaskRecords,
    Sessions,
    Attempts,
    SkillDifficultyStates,
    SyncOutboxEntries,
    InsightCards,
  ],
)
class IkamvaDatabase extends _$IkamvaDatabase {
  IkamvaDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(sessions, sessions.baselineAccuracy);
        await m.createTable(skillDifficultyStates);
      }
      if (from < 3) {
        await m.addColumn(taskRecords, taskRecords.contentHash);
        await m.createTable(insightCards);
      }
      if (from < 4) {
        // Legacy `cached` rows were dev seeds / fallbacks (TASKS §3.9, §8.6).
        await customStatement(
          "UPDATE task_records SET source = 'dev_seed_only' WHERE source = 'cached'",
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}
