import 'package:drift/drift.dart';

import '../config/learner_content_policy.dart';
import '../db/app_database.dart';
import 'practice_task_config.dart';

export 'practice_task_config.dart';

/// Serves [TaskRecord] rows for a quest or free practice (TASKS §4.1).
///
/// Tasks are matched to a [Quest] by **topic** (there is no `questId` on
/// [TaskRecords] yet). Caps results with [Quest.maxTasks] when set.
///
/// Optional [maxDifficultyInclusive] filters `task.difficulty` for adaptive
/// play (TASKS §5).
class GameCoordinator {
  GameCoordinator(this._db);

  final IkamvaDatabase _db;

  /// Tasks for the quest’s topic, oldest-first, capped by [Quest.maxTasks].
  Future<List<TaskRecord>> loadTasksForQuest(
    Quest quest, {
    int? maxDifficultyInclusive,
  }) async {
    final rows = await (_db.select(_db.taskRecords)
          ..where(
            (t) => _topicDifficultySkillPredicate(
              t,
              quest.topic,
              maxDifficultyInclusive,
              null,
            ),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return _cap(_filterSkill(rows, null), quest.maxTasks);
  }

  /// Reactive task list for the quest’s topic (same ordering and caps).
  Stream<List<TaskRecord>> watchTasksForQuest(
    Quest quest, {
    int? maxDifficultyInclusive,
  }) {
    final cap = quest.maxTasks;
    return (_db.select(_db.taskRecords)
          ..where(
            (t) => _topicDifficultySkillPredicate(
              t,
              quest.topic,
              maxDifficultyInclusive,
              null,
            ),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch()
        .map((rows) => _cap(_filterSkill(rows, null), cap));
  }

  /// Practice: optional topic and skill filters, always capped by [config.maxTasks].
  Future<List<TaskRecord>> loadTasksForPractice(PracticeTaskConfig config) async {
    final List<TaskRecord> rows;
    if (config.topic != null) {
      rows = await (_db.select(_db.taskRecords)
            ..where(
              (t) => _topicDifficultySkillPredicate(
                t,
                config.topic!,
                config.maxDifficultyInclusive,
                config.skillId,
              ),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();
    } else {
      rows = await (_db.select(_db.taskRecords)
            ..where(
              (t) => _difficultySkillPredicate(
                t,
                config.maxDifficultyInclusive,
                config.skillId,
              ),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();
    }
    return _cap(_filterSkill(rows, config.skillId), config.maxTasks);
  }

  Stream<List<TaskRecord>> watchTasksForPractice(PracticeTaskConfig config) {
    final cap = config.maxTasks;
    final skill = config.skillId;
    final maxD = config.maxDifficultyInclusive;
    if (config.topic != null) {
      return (_db.select(_db.taskRecords)
            ..where(
              (t) => _topicDifficultySkillPredicate(
                t,
                config.topic!,
                maxD,
                skill,
              ),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch()
          .map((rows) => _cap(_filterSkill(rows, skill), cap));
    }
    return (_db.select(_db.taskRecords)
          ..where((t) => _difficultySkillPredicate(t, maxD, skill))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch()
        .map((rows) => _cap(_filterSkill(rows, skill), cap));
  }

  Expression<bool> _topicDifficultySkillPredicate(
    $TaskRecordsTable t,
    String topic,
    int? maxDifficultyInclusive,
    String? skillId,
  ) {
    Expression<bool> e = t.topic.equals(topic) &
        LearnerContentPolicy.taskRowAllowed(t);
    if (maxDifficultyInclusive != null) {
      e = e & t.difficulty.isSmallerOrEqualValue(maxDifficultyInclusive);
    }
    if (skillId != null && skillId.isNotEmpty) {
      e = e & t.skillId.equals(skillId);
    }
    return e;
  }

  Expression<bool> _difficultySkillPredicate(
    $TaskRecordsTable t,
    int? maxDifficultyInclusive,
    String? skillId,
  ) {
    Expression<bool> e = LearnerContentPolicy.taskRowAllowed(t);
    if (maxDifficultyInclusive != null) {
      e = e & t.difficulty.isSmallerOrEqualValue(maxDifficultyInclusive);
    }
    if (skillId != null && skillId.isNotEmpty) {
      e = e & t.skillId.equals(skillId);
    }
    return e;
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
