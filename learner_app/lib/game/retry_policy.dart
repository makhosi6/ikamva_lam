/// Per-task submission cap for wrong answers (TASKS §4.4).
///
/// [maxRetries] is the number of **extra** tries after the first submission
/// (e.g. `2` → up to `3` submissions on the same task before the UI should
/// force advance after a wrong answer).
class PerTaskRetryPolicy {
  PerTaskRetryPolicy({this.maxRetries = 2});

  final int maxRetries;

  int _submissionsThisTask = 0;

  int get maxSubmissionsPerTask => maxRetries + 1;

  /// Submissions already completed on the current task (0 before first submit).
  int get submissionCount => _submissionsThisTask;

  /// Clears counters when moving to a new task.
  void resetForNewTask() => _submissionsThisTask = 0;

  /// Whether another submission is allowed on the current task.
  bool get canSubmit => _submissionsThisTask < maxSubmissionsPerTask;

  /// Call after the learner submits an answer for the current task.
  void recordSubmission() {
    _submissionsThisTask++;
  }
}
