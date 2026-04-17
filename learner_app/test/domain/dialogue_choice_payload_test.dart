import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/tasks/dialogue_choice_payload.dart';

void main() {
  group('DialogueChoicePayload', () {
    test('parses string options with correct_index', () {
      final p = DialogueChoicePayload.fromJson({
        'context': 'At the shop.',
        'question': 'What do you say?',
        'options': ['Please', 'Thank you', 'Goodbye'],
        'correct_index': 1,
      });
      expect(p.resolvedCorrectIndex, 1);
      expect(p.options[1].text, 'Thank you');
      expect(p.options[1].id, '1');
    });

    test('parses object options with correct_id', () {
      final p = DialogueChoicePayload.fromJson({
        'context': 'Morning.',
        'question': 'Greeting?',
        'options': [
          {'id': 'a', 'text': 'Hi'},
          {'id': 'b', 'label': 'Hello'},
        ],
        'correct_id': 'b',
      });
      expect(p.resolvedCorrectIndex, 1);
    });

    test('toJson round-trips index form', () {
      final a = DialogueChoicePayload.fromJson({
        'context': 'c',
        'question': 'q',
        'options': ['x', 'y'],
        'correct_index': 0,
      });
      final b = DialogueChoicePayload.fromJson(a.toJson());
      expect(b.resolvedCorrectIndex, 0);
      expect(b.context, 'c');
    });

    test('rejects both correct keys', () {
      expect(
        () => DialogueChoicePayload.fromJson({
          'context': 'c',
          'question': 'q',
          'options': ['a', 'b'],
          'correct_index': 0,
          'correct_id': 'a',
        }),
        throwsFormatException,
      );
    });

    test('rejects neither correct key', () {
      expect(
        () => DialogueChoicePayload.fromJson({
          'context': 'c',
          'question': 'q',
          'options': ['a', 'b'],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown correct_id', () {
      expect(
        () => DialogueChoicePayload.fromJson({
          'context': 'c',
          'question': 'q',
          'options': [
            {'id': 'a', 'text': 'A'},
            {'id': 'b', 'text': 'B'},
          ],
          'correct_id': 'z',
        }),
        throwsFormatException,
      );
    });

    test('tryParseJsonString returns null for bad JSON', () {
      expect(DialogueChoicePayload.tryParseJsonString(''), isNull);
      expect(DialogueChoicePayload.tryParseJsonString('[]'), isNull);
    });
  });
}
