import 'package:drift/drift.dart';

import '../db/app_database.dart';

class AttemptRepository {
  AttemptRepository(this._db);

  final IkamvaDatabase _db;

  /// Correctness of the last [limit] attempts before [beforeExclusive] (any skill).
  Future<List<bool>> recentCorrectnessBefore({
    required DateTime beforeExclusive,
    int limit = 10,
  }) async {
    final rows = await (_db.select(_db.attempts)
          ..where((a) => a.timestamp.isSmallerThanValue(beforeExclusive))
          ..orderBy([
            (a) => OrderingTerm(expression: a.timestamp, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
    return rows.map((a) => a.correct).toList();
  }

  /// Fraction correct in the rolling window, or null if there are no attempts.
  Future<double?> rollingAccuracyOverallBefore({
    required DateTime beforeExclusive,
    int windowSize = 10,
  }) async {
    final bits = await recentCorrectnessBefore(
      beforeExclusive: beforeExclusive,
      limit: windowSize,
    );
    if (bits.isEmpty) return null;
    return bits.where((c) => c).length / bits.length;
  }

  /// Last [windowSize] attempts for [skillId], newest first; optional time cutoff.
  Future<double?> rollingAccuracyForSkill(
    String skillId, {
    int windowSize = 10,
    DateTime? beforeExclusive,
  }) async {
    final beforeSql =
        beforeExclusive != null ? 'AND a.timestamp < ?' : '';
    final vars = <Variable<Object>>[Variable.withString(skillId)];
    if (beforeExclusive != null) {
      vars.add(Variable.withDateTime(beforeExclusive));
    }
    vars.add(Variable.withInt(windowSize));

    final rows = await _db.customSelect(
      'SELECT a.correct AS c FROM attempts AS a '
      'INNER JOIN task_records AS t ON t.id = a.task_id '
      'WHERE t.skill_id = ? $beforeSql '
      'ORDER BY a.timestamp DESC LIMIT ?',
      variables: vars,
      readsFrom: {_db.attempts, _db.taskRecords},
    ).get();
    if (rows.isEmpty) return null;
    var correct = 0;
    for (final row in rows) {
      if (row.read<bool>('c')) correct++;
    }
    return correct / rows.length;
  }

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
