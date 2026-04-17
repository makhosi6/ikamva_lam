import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/tasks/reorder_payload.dart';

void main() {
  group('ReorderPayload', () {
    test('parses tokens and correct_order', () {
      final p = ReorderPayload.fromJson({
        'tokens': ['like', 'I', 'apples'],
        'correct_order': [1, 0, 2],
      });
      expect(p.sentenceText(), 'I like apples');
    });

    test('tryParseJsonString round-trips', () {
      const raw =
          '{"tokens":["go","We","school"],"correct_order":[1,0,2]}';
      final a = ReorderPayload.tryParseJsonString(raw);
      expect(a, isNotNull);
      final b = ReorderPayload.tryParseJsonString(a!.toJsonString());
      expect(b!.tokens, a.tokens);
      expect(b.correctOrder, a.correctOrder);
    });

    test('rejects too few tokens', () {
      expect(
        () => ReorderPayload.fromJson({
          'tokens': ['only'],
          'correct_order': [0],
        }),
        throwsFormatException,
      );
    });

    test('rejects non-permutation order', () {
      expect(
        () => ReorderPayload.fromJson({
          'tokens': ['a', 'b', 'c'],
          'correct_order': [0, 0, 2],
        }),
        throwsFormatException,
      );
      expect(
        () => ReorderPayload.fromJson({
          'tokens': ['a', 'b'],
          'correct_order': [0, 1, 2],
        }),
        throwsFormatException,
      );
    });

    test('tryParseJsonString returns null for bad JSON', () {
      expect(ReorderPayload.tryParseJsonString(''), isNull);
      expect(ReorderPayload.tryParseJsonString('[]'), isNull);
    });
  });
}
