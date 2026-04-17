/// Task kinds stored on [TaskRecords.taskType].
enum TaskType {
  cloze('cloze'),
  reorder('reorder'),
  match('match'),
  dialogueChoice('dialogue_choice');

  const TaskType(this.storageValue);

  final String storageValue;

  static TaskType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final t in TaskType.values) {
      if (t.storageValue == raw) return t;
    }
    return null;
  }

  static TaskType parse(String raw) {
    final v = tryParse(raw);
    if (v == null) {
      throw FormatException('Unknown TaskType: $raw');
    }
    return v;
  }
}
