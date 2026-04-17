import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'practice_task_config.dart';

export 'practice_task_config.dart';

/// Serves [TaskRecord] rows for a quest or free practice (TASKS §4.1).
///
/// Tasks are matched to a [Quest] by **topic** (there is no `questId` on
/// [TaskRecords] yet). Caps results with [Quest.maxTasks] when set.
class GameCoordinator {
  GameCoordinator(this._db);

  final IkamvaDatabase _db;

  /// Tasks for the quest’s topic, oldest-first, capped by [Quest.maxTasks].
  Future<List<TaskRecord>> loadTasksForQuest(Quest quest) async {
    final rows = await (_db.select(_db.taskRecords)
          ..where((t) => t.topic.equals(quest.topic))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return _cap(_filterSkill(rows, null), quest.maxTasks);
  }

  /// Reactive task list for the quest’s topic (same ordering and caps).
  Stream<List<TaskRecord>> watchTasksForQuest(Quest quest) {
    final cap = quest.maxTasks;
    return (_db.select(_db.taskRecords)
          ..where((t) => t.topic.equals(quest.topic))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch()
        .map((rows) => _cap(_filterSkill(rows, null), cap));
  }

  /// Practice: optional topic and skill filters, always capped by [config.maxTasks].
  Future<List<TaskRecord>> loadTasksForPractice(PracticeTaskConfig config) async {
    final List<TaskRecord> rows;
    if (config.topic != null) {
      rows = await (_db.select(_db.taskRecords)
            ..where((t) => t.topic.equals(config.topic!))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();
    } else {
      rows = await (_db.select(_db.taskRecords)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();
    }
    return _cap(_filterSkill(rows, config.skillId), config.maxTasks);
  }

  Stream<List<TaskRecord>> watchTasksForPractice(PracticeTaskConfig config) {
    final cap = config.maxTasks;
    final skill = config.skillId;
    if (config.topic != null) {
      return (_db.select(_db.taskRecords)
            ..where((t) => t.topic.equals(config.topic!))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch()
          .map((rows) => _cap(_filterSkill(rows, skill), cap));
    }
    return (_db.select(_db.taskRecords)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch()
        .map((rows) => _cap(_filterSkill(rows, skill), cap));
  }

  List<TaskRecord> _filterSkill(List<TaskRecord> rows, String? skillId) {
    if (skillId == null || skillId.isEmpty) return rows;
    return rows.where((r) => r.skillId == skillId).toList();
  }

  List<TaskRecord> _cap(List<TaskRecord> rows, int? maxTasks) {
    if (maxTasks == null || maxTasks <= 0) return rows;
    if (rows.length <= maxTasks) return rows;
    return rows.take(maxTasks).toList();
  }
}
