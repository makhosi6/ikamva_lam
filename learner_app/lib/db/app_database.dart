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
  ],
)
class IkamvaDatabase extends _$IkamvaDatabase {
  IkamvaDatabase(super.executor);

  @override
  int get schemaVersion => 2;

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
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}
