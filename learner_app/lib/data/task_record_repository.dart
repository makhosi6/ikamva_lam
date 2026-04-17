import 'package:drift/drift.dart';

import '../db/app_database.dart';

class TaskRecordRepository {
  TaskRecordRepository(this._db);

  final IkamvaDatabase _db;

  Future<TaskRecord?> getById(String id) {
    return (_db.select(_db.taskRecords)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<TaskRecord>> listAll() => _db.select(_db.taskRecords).get();

  Future<List<TaskRecord>> listByTopic(String topic) {
    return (_db.select(_db.taskRecords)
          ..where((t) => t.topic.equals(topic))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Stream<List<TaskRecord>> watchAll() => _db.select(_db.taskRecords).watch();

  Future<void> insert(TaskRecordsCompanion row) =>
      _db.into(_db.taskRecords).insert(row);

  Future<void> upsert(TaskRecordsCompanion row) =>
      _db.into(_db.taskRecords).insertOnConflictUpdate(row);

  Future<int> deleteById(String id) {
    return (_db.delete(_db.taskRecords)..where((t) => t.id.equals(id))).go();
  }
}
