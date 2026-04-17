/// Slot values shared by all `TASK: generate_*` templates (TASKS §7.1).
class PromptSlots {
  const PromptSlots({
    required this.level,
    required this.topic,
    required this.skill,
    required this.difficultyStep,
  });

  final String level;
  final String topic;
  final String skill;

  /// Adaptive step label (e.g. `1`–`5` or engine-specific).
  final String difficultyStep;
}
