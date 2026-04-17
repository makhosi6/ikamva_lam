import 'package:drift/drift.dart';

import '../db/app_database.dart';

class QuestRepository {
  QuestRepository(this._db);

  final IkamvaDatabase _db;

  Future<Quest?> getById(String id) {
    return (_db.select(_db.quests)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Quest>> listAll() => _db.select(_db.quests).get();

  Future<List<Quest>> listActive({DateTime? at}) {
    final when = at ?? DateTime.now().toUtc();
    return (_db.select(_db.quests)
          ..where((q) => q.isActive.equals(true))
          ..where((q) => q.startsAt.isSmallerOrEqualValue(when))
          ..where((q) => q.endsAt.isBiggerOrEqualValue(when)))
        .get();
  }

  Stream<List<Quest>> watchAll() => _db.select(_db.quests).watch();

  Future<void> insert(QuestsCompanion row) => _db.into(_db.quests).insert(row);

  Future<void> upsert(QuestsCompanion row) =>
      _db.into(_db.quests).insertOnConflictUpdate(row);

  Future<int> deleteById(String id) {
    return (_db.delete(_db.quests)..where((t) => t.id.equals(id))).go();
  }
}
