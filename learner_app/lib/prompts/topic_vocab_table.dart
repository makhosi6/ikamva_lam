/// Parses [topic_vocab.txt](asset) for curriculum-aligned word hints (TASKS §7.3).
class TopicVocabTable {
  TopicVocabTable(this._byTopic);

  final Map<String, String> _byTopic;

  String vocabForTopic(String topic) {
    final k = topic.trim().toLowerCase();
    if (k.isEmpty) {
      return _byTopic['default'] ?? '';
    }
    return _byTopic[k] ?? _byTopic['default'] ?? '';
  }

  static TopicVocabTable parse(String raw) {
    final map = <String, String>{};
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final idx = t.indexOf('|');
      if (idx <= 0) continue;
      final key = t.substring(0, idx).trim().toLowerCase();
      final val = t.substring(idx + 1).trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        map[key] = val;
      }
    }
    return TopicVocabTable(map);
  }
}
