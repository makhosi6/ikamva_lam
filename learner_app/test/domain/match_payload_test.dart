import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/tasks/match_payload.dart';

void main() {
  group('MatchPayload', () {
    test('parses pairs as list of int pairs', () {
      final p = MatchPayload.fromJson({
        'left': ['cat', 'dog'],
        'right': ['kitten', 'puppy'],
        'pairs': [
          [0, 1],
          [1, 0],
        ],
      });
      expect(p.left, ['cat', 'dog']);
      expect(p.pairs, hasLength(2));
      expect(p.pairs[0].leftIndex, 0);
      expect(p.pairs[0].rightIndex, 1);
    });

    test('parses pairs as list of objects', () {
      final p = MatchPayload.fromJson({
        'left': ['a', 'b'],
        'right': ['1', '2'],
        'pairs': [
          {'left': 0, 'right': 0},
          {'left': 1, 'right': 1},
        ],
      });
      expect(p.pairs[1].rightIndex, 1);
    });

    test('parses pairs as string-keyed map', () {
      final p = MatchPayload.fromJson({
        'left': ['x', 'y'],
        'right': ['p', 'q'],
        'pairs': {'0': 1, '1': 0},
      });
      expect(p.pairs, hasLength(2));
    });

    test('tryParseJsonString round-trips', () {
      const raw =
          '{"left":["a","b"],"right":["c","d"],"pairs":[[0,0],[1,1]]}';
      final a = MatchPayload.tryParseJsonString(raw);
      expect(a, isNotNull);
      final b = MatchPayload.tryParseJsonString(a!.toJsonString());
      expect(b!.left, a.left);
      expect(b.pairs.map((e) => e.toJsonList()), [
        [0, 0],
        [1, 1],
      ]);
    });

    test('rejects column length mismatch', () {
      expect(
        () => MatchPayload.fromJson({
          'left': ['a'],
          'right': ['b', 'c'],
          'pairs': [
            [0, 0],
            [1, 1],
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects non-bijection pairs', () {
      expect(
        () => MatchPayload.fromJson({
          'left': ['a', 'b'],
          'right': ['c', 'd'],
          'pairs': [
            [0, 0],
            [0, 1],
          ],
        }),
        throwsFormatException,
      );
    });

    test('tryParseJsonString returns null for bad JSON', () {
      expect(MatchPayload.tryParseJsonString('{'), isNull);
      expect(MatchPayload.tryParseJsonString('[]'), isNull);
    });
  });
}
