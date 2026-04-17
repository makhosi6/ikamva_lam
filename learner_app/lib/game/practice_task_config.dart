/// Practice-mode task selection when no [Quest] row is active (TASKS §4.1).
class PracticeTaskConfig {
  const PracticeTaskConfig({
    this.topic,
    this.skillId,
    this.maxTasks = 20,
  });

  /// When null, all cached/generated tasks are considered (still capped by [maxTasks]).
  final String? topic;

  /// When non-null, only tasks whose `skillId` column equals this value.
  final String? skillId;

  /// Hard cap on how many tasks to return per load/watch emission.
  final int maxTasks;
}
