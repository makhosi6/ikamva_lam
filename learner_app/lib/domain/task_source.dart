/// How a task row was produced (TASKS §2.4).
enum TaskSource {
  cached('cached'),
  generated('generated');

  const TaskSource(this.storageValue);

  final String storageValue;

  static TaskSource? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in TaskSource.values) {
      if (s.storageValue == raw) return s;
    }
    return null;
  }

  static TaskSource parse(String raw) {
    final v = tryParse(raw);
    if (v == null) {
      throw FormatException('Unknown TaskSource: $raw');
    }
    return v;
  }
}
