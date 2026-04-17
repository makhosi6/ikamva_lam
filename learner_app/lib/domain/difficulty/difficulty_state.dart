/// In-memory view of adaptive difficulty for one skill strand (TASKS §5.1).
///
/// Persisted form: `skill_difficulty_states` rows (see Drift `SkillDifficultyState`).
class DifficultyState {
  const DifficultyState({
    required this.skillId,
    required this.step,
    required this.maxStep,
    required this.hintFirstMode,
  });

  final String skillId;

  /// Current difficulty step (1…[maxStep]), aligned with [TaskRecord.difficulty].
  final int step;

  /// Upper bound from the active [Quest.maxDifficultyStep].
  final int maxStep;

  /// When true, the UI should encourage reading hints before submitting.
  final bool hintFirstMode;
}
