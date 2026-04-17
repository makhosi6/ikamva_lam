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
    SyncOutboxEntries,
  ],
)
class IkamvaDatabase extends _$IkamvaDatabase {
  IkamvaDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}
