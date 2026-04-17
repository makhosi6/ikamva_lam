import 'package:drift/drift.dart';

import '../db/app_database.dart';

class SessionRepository {
  SessionRepository(this._db);

  final IkamvaDatabase _db;

  Future<Session?> getById(String id) {
    return (_db.select(_db.sessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Session>> listForQuest(String questId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.questId.equals(questId))
          ..orderBy([(s) => OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<Session>> watchAll() => _db.select(_db.sessions).watch();

  Future<void> insert(SessionsCompanion row) =>
      _db.into(_db.sessions).insert(row);

  Future<void> update(String id, SessionsCompanion companion) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<int> deleteById(String id) {
    return (_db.delete(_db.sessions)..where((t) => t.id.equals(id))).go();
  }
}
