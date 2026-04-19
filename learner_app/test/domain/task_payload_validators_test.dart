import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/db/seed.dart';
import 'package:ikamva_lam/domain/tasks/cloze_payload.dart';
import 'package:ikamva_lam/domain/tasks/dialogue_choice_payload.dart';
import 'package:ikamva_lam/domain/tasks/match_payload.dart';
import 'package:ikamva_lam/domain/tasks/reorder_payload.dart';
import 'package:ikamva_lam/domain/tasks/task_payload_validators.dart';
import 'package:ikamva_lam/domain/tasks/task_text_policy.dart';

void main() {
  group('countWords', () {
    test('counts trimmed whitespace segments', () {
      expect(countWords('  a   b c  '), 3);
      expect(countWords(''), 0);
    });
  });

  group('TaskPayloadValidators.validateCloze', () {
    test('accepts dev seed cloze at A1', () {
      final p = ClozePayload.tryParseJsonString(kSeedClozePayloadJson)!;
      expect(TaskPayloadValidators.validateCloze(p, 'A1'), isEmpty);
    });

    test('rejects duplicate options', () {
      final p = ClozePayload.fromJson({
        'sentence': 'We ___ here now.',
        'answer': 'eat',
        'options': ['eat', 'Eat', 'runs', 'jumps'],
      });
      expect(
        TaskPayloadValidators.validateCloze(p, 'A1').single,
        contains('duplicate options'),
      );
    });

    test('rejects answer not in options', () {
      final p = ClozePayload.fromJson({
        'sentence': 'I ___ apples.',
        'answer': 'like',
        'options': ['hate', 'see', 'want'],
      });
      expect(
        TaskPayloadValidators.validateCloze(p, 'A1').single,
        contains('answer must appear'),
      );
    });

    test('rejects sentence without a ___ blank', () {
      final p = ClozePayload.fromJson({
        'sentence': 'I like apples.',
        'answer': 'like',
        'options': ['like', 'hate', 'see', 'want'],
      });
      expect(
        TaskPayloadValidators.validateCloze(p, 'A1').single,
        contains('exactly one'),
      );
    });

    test('rejects sentence with two ___ blanks', () {
      final p = ClozePayload.fromJson({
        'sentence': 'I ___ apples and she ___ pears.',
        'answer': 'like',
        'options': ['like', 'hate', 'see', 'want'],
      });
      expect(
        TaskPayloadValidators.validateCloze(p, 'A1').single,
        contains('exactly one'),
      );
    });

    test('rejects sentence over A1 word cap', () {
      final p = ClozePayload.fromJson({
        'sentence':
            'one two three four five six seven eight nine ten ___ eleven',
        'answer': 'x',
        'options': ['x', 'y', 'z', 'w'],
      });
      expect(
        TaskPayloadValidators.validateCloze(p, 'A1').single,
        contains('max 10'),
      );
    });
  });

  group('TaskPayloadValidators.validateReorder', () {
    test('rejects duplicate tokens', () {
      final p = ReorderPayload.fromJson({
        'tokens': ['Hi', 'hi', 'there'],
        'correct_order': [0, 1, 2],
      });
      expect(
        TaskPayloadValidators.validateReorder(p, 'A1').single,
        contains('duplicate tokens'),
      );
    });

    test('rejects token over word cap', () {
      final p = ReorderPayload.fromJson({
        'tokens': ['a b c d e', 'x'],
        'correct_order': [0, 1],
      });
      expect(
        TaskPayloadValidators.validateReorder(p, 'A1').single,
        contains('token[0]'),
      );
    });
  });

  group('TaskPayloadValidators.validateMatch', () {
    test('rejects duplicate left column', () {
      final p = MatchPayload.fromJson({
        'left': ['X', 'x'],
        'right': ['p', 'q'],
        'pairs': [
          [0, 0],
          [1, 1],
        ],
      });
      expect(
        TaskPayloadValidators.validateMatch(p, 'A1').single,
        contains('duplicate left'),
      );
    });
  });

  group('TaskPayloadValidators.validateDialogueChoice', () {
    test('rejects duplicate option text', () {
      final p = DialogueChoicePayload.fromJson({
        'context': 'Shop.',
        'question': 'You?',
        'options': [
          {'id': 'a', 'text': 'Hi'},
          {'id': 'b', 'text': 'hi'},
        ],
        'correct_id': 'a',
      });
      expect(
        TaskPayloadValidators.validateDialogueChoice(p, 'A1').single,
        contains('duplicate option text'),
      );
    });
  });
}
