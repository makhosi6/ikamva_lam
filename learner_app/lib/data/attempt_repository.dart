import 'package:drift/drift.dart';

import '../db/app_database.dart';

class AttemptRepository {
  AttemptRepository(this._db);

  final IkamvaDatabase _db;

  Future<Attempt?> getById(String id) {
    return (_db.select(_db.attempts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Attempt>> listForSession(String sessionId) {
    return (_db.select(_db.attempts)
          ..where((a) => a.sessionId.equals(sessionId))
          ..orderBy([(a) => OrderingTerm(expression: a.timestamp)]))
        .get();
  }

  Future<List<Attempt>> listForTask(String taskId) {
    return (_db.select(_db.attempts)
          ..where((a) => a.taskId.equals(taskId))
          ..orderBy([(a) => OrderingTerm(expression: a.timestamp)]))
        .get();
  }

  Future<void> insert(AttemptsCompanion row) =>
      _db.into(_db.attempts).insert(row);

  Future<int> deleteById(String id) {
    return (_db.delete(_db.attempts)..where((t) => t.id.equals(id))).go();
  }
}
