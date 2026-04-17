/// Simple rule buckets for export / teacher views (TASKS §11.2).
abstract final class ErrorClustering {
  static String bucketForSkill(String skillId) {
    if (skillId.contains('grammar_tense')) return 'grammar_tense';
    if (skillId.contains('grammar_plural')) return 'grammar_plural';
    if (skillId.contains('grammar_articles')) return 'grammar_articles';
    if (skillId.contains('sentence')) return 'sentence_structure';
    return 'vocabulary';
  }
}
