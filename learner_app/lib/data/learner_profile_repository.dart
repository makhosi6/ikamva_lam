import '../db/app_database.dart';

class LearnerProfileRepository {
  LearnerProfileRepository(this._db);

  final IkamvaDatabase _db;

  Future<LearnerProfile?> getById(String id) {
    return (_db.select(_db.learnerProfiles)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<LearnerProfile>> listAll() => _db.select(_db.learnerProfiles).get();

  Stream<List<LearnerProfile>> watchAll() =>
      _db.select(_db.learnerProfiles).watch();

  Future<void> insert(LearnerProfilesCompanion row) =>
      _db.into(_db.learnerProfiles).insert(row);

  Future<void> upsert(LearnerProfilesCompanion row) =>
      _db.into(_db.learnerProfiles).insertOnConflictUpdate(row);

  Future<int> deleteById(String id) {
    return (_db.delete(_db.learnerProfiles)..where((t) => t.id.equals(id))).go();
  }
}
