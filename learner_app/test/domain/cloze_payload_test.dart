import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/tasks/cloze_payload.dart';

void main() {
  const validJson = '{'
      '"sentence":"I like to ___ fruit.",'
      '"answer":"eat",'
      '"options":["eat","eats","eating","ate"]'
      '}';

  group('ClozePayload', () {
    test('tryParseJsonString accepts seed-shaped payload', () {
      final p = ClozePayload.tryParseJsonString(validJson);
      expect(p, isNotNull);
      expect(p!.sentence, 'I like to ___ fruit.');
      expect(p.answer, 'eat');
      expect(p.options, ['eat', 'eats', 'eating', 'ate']);
      expect(p.hintEn, isNull);
    });

    test('fromJson accepts optional multilingual hints', () {
      final p = ClozePayload.fromJson({
        'sentence': 'We ___ to school.',
        'answer': 'go',
        'options': ['go', 'goes', 'going'],
        'hint_en': 'Present tense.',
        'hint_xh': 'Ixesha langoku.',
        'hint_zu': null,
        'hint_af': ' ',
      });
      expect(p.hintEn, 'Present tense.');
      expect(p.hintXh, 'Ixesha langoku.');
      expect(p.hintZu, isNull);
      expect(p.hintAf, isNull);
    });

    test('toJson round-trips', () {
      final a = ClozePayload.fromJson({
        'sentence': 'A ___ B.',
        'answer': 'b',
        'options': ['a', 'b', 'c'],
      });
      final b = ClozePayload.fromJson(a.toJson());
      expect(b.sentence, a.sentence);
      expect(b.answer, a.answer);
      expect(b.options, a.options);
    });

    test('rejects wrong option count', () {
      expect(
        () => ClozePayload.fromJson({
          'sentence': 'x',
          'answer': 'y',
          'options': ['a', 'b'],
        }),
        throwsFormatException,
      );
      expect(
        () => ClozePayload.fromJson({
          'sentence': 'x',
          'answer': 'y',
          'options': ['a', 'b', 'c', 'd', 'e'],
        }),
        throwsFormatException,
      );
    });

    test('tryParseJsonString returns null for invalid JSON', () {
      expect(ClozePayload.tryParseJsonString('not json'), isNull);
      expect(ClozePayload.tryParseJsonString('[]'), isNull);
      expect(ClozePayload.tryParseJsonString('{}'), isNull);
    });
  });
}
