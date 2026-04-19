/// How a task row was produced (TASKS §2.4, §3.9, §8.6).
///
/// **Production learner sessions** should only use [generated] and
/// [cachedGenerated]. [devSeedOnly] is for bundled dev/test fixtures.
enum TaskSource {
  /// Fresh model output inserted for this row.
  generated('generated'),

  /// Pre-generated earlier and stored for reuse (still model-authored).
  cachedGenerated('cached_generated'),

  /// Bundled / copied workbook-style fixtures — not for release learner play.
  devSeedOnly('dev_seed_only');

  const TaskSource(this.storageValue);

  final String storageValue;

  static TaskSource? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in TaskSource.values) {
      if (s.storageValue == raw) return s;
    }
    // Legacy DB value (schema &lt; v4): treat as dev seed semantics.
    if (raw == 'cached') return TaskSource.devSeedOnly;
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
