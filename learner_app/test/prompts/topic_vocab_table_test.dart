import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/prompts/topic_vocab_table.dart';

void main() {
  test('parse and lookup', () {
    const raw = '''
# c
default|fallback
food|eggs
''';
    final t = TopicVocabTable.parse(raw);
    expect(t.vocabForTopic('food'), 'eggs');
    expect(t.vocabForTopic('unknown'), 'fallback');
  });
}
