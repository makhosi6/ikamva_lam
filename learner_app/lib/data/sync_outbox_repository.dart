import '../db/app_database.dart';

class SyncOutboxRepository {
  SyncOutboxRepository(this._db);

  final IkamvaDatabase _db;

  Future<SyncOutboxEntry?> getById(String id) {
    return (_db.select(_db.syncOutboxEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Pending rows (no success semantics yet — Phase 14).
  Future<List<SyncOutboxEntry>> listAll() =>
      _db.select(_db.syncOutboxEntries).get();

  Stream<List<SyncOutboxEntry>> watchAll() =>
      _db.select(_db.syncOutboxEntries).watch();

  Future<void> insert(SyncOutboxEntriesCompanion row) =>
      _db.into(_db.syncOutboxEntries).insert(row);

  Future<void> update(String id, SyncOutboxEntriesCompanion companion) {
    return (_db.update(_db.syncOutboxEntries)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<int> deleteById(String id) {
    return (_db.delete(_db.syncOutboxEntries)..where((t) => t.id.equals(id))).go();
  }
}
