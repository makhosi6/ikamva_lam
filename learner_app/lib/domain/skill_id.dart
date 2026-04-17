/// Canonical skill identifiers (spec §4.1, TASKS §2.3). Stored as [storageValue] in SQLite.
enum SkillId {
  vocabulary('vocabulary'),
  sentenceStructure('sentence_structure'),
  grammarTense('grammar_tense'),
  grammarPlural('grammar_plural'),
  grammarArticles('grammar_articles');

  const SkillId(this.storageValue);

  final String storageValue;

  static SkillId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in SkillId.values) {
      if (s.storageValue == raw) return s;
    }
    return null;
  }

  static SkillId parse(String raw) {
    final v = tryParse(raw);
    if (v == null) {
      throw FormatException('Unknown SkillId: $raw');
    }
    return v;
  }
}
