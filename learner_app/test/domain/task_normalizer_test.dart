import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/task_type.dart';
import 'package:ikamva_lam/domain/tasks/cloze_payload.dart';
import 'package:ikamva_lam/domain/tasks/task_normalizer.dart';

void main() {
  group('TaskNormalizer', () {
    test('cloze: maps stem + choices to sentence + options', () {
      final logs = <String>[];
      final n = TaskNormalizer(log: logs.add);
      const raw = '''
{"stem":"I ___ apples.","answer":"like","choices":["like","hate","see","want"]}
''';
      final m = n.normalizeJson(TaskType.cloze, raw);
      expect(m, isNotNull);
      expect(m!['sentence'], 'I ___ apples.');
      expect(m['options'], ['like', 'hate', 'see', 'want']);
      final p = ClozePayload.fromJson(m);
      expect(p.answer, 'like');
    });

    test('reorder: maps pieces + correctOrder', () {
      final n = TaskNormalizer(log: (_) {});
      final m = n.normalizeJson(
        TaskType.reorder,
        '{"pieces":["to","school","We"],"correctOrder":[2,0,1]}',
      );
      expect(m, isNotNull);
      expect(m!['tokens'], ['to', 'school', 'We']);
      expect(m['correct_order'], [2, 0, 1]);
    });

    test('dialogue: maps scenario + prompt + correctIndex', () {
      final n = TaskNormalizer(log: (_) {});
      final m = n.normalizeJson(
        TaskType.dialogueChoice,
        '{"scenario":"Store.","prompt":"Thanks?","options":["No","Yes"],"correctIndex":1}',
      );
      expect(m, isNotNull);
      expect(m!['context'], 'Store.');
      expect(m['question'], 'Thanks?');
      expect(m['correct_index'], 1);
    });

    test('returns null and logs for unusable JSON', () {
      final logs = <String>[];
      final n = TaskNormalizer(log: logs.add);
      final m = n.normalizeJson(TaskType.cloze, '{"foo":1}');
      expect(m, isNull);
      expect(logs.any((l) => l.contains('missing')), isTrue);
    });
  });
}
