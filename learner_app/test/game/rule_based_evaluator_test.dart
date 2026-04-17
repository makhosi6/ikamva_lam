import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/db/app_database.dart';
import 'package:ikamva_lam/domain/skill_id.dart';
import 'package:ikamva_lam/domain/task_source.dart';
import 'package:ikamva_lam/domain/task_type.dart';
import 'package:ikamva_lam/game/rule_based_evaluator.dart';

void main() {
  const eval = RuleBasedEvaluator();

  group('RuleBasedEvaluator', () {
    test('cloze: correct by choice key', () {
      final task = TaskRecord(
        id: 't1',
        taskType: TaskType.cloze.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson:
            '{"sentence":"I ___ .","answer":"run","options":["run","walk","sit","eat"]}',
        source: TaskSource.cached.storageValue,
        createdAt: DateTime.utc(2026),
      );
      expect(
        eval.evaluate(task, '{"choice":"run"}').correct,
        isTrue,
      );
      expect(
        eval.evaluate(task, '{"choice":"walk"}').correct,
        isFalse,
      );
    });

    test('reorder: order must match', () {
      final task = TaskRecord(
        id: 't2',
        taskType: TaskType.reorder.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson:
            '{"tokens":["like","I","apples"],"correct_order":[1,0,2]}',
        source: TaskSource.cached.storageValue,
        createdAt: DateTime.utc(2026),
      );
      expect(
        eval.evaluate(task, '{"order":[1,0,2]}').correct,
        isTrue,
      );
      expect(
        eval.evaluate(task, '{"order":[0,1,2]}').correct,
        isFalse,
      );
    });

    test('match: pairs as set', () {
      final task = TaskRecord(
        id: 't3',
        taskType: TaskType.match.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: '{'
            '"left":["cat","dog"],'
            '"right":["kitten","puppy"],'
            '"pairs":[[0,1],[1,0]]'
            '}',
        source: TaskSource.cached.storageValue,
        createdAt: DateTime.utc(2026),
      );
      expect(
        eval.evaluate(task, '{"pairs":[[0,1],[1,0]]}').correct,
        isTrue,
      );
      expect(
        eval.evaluate(task, '{"pairs":[[0,0],[1,1]]}').correct,
        isFalse,
      );
    });

    test('dialogue: index', () {
      final task = TaskRecord(
        id: 't4',
        taskType: TaskType.dialogueChoice.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: '{'
            '"context":"Shop",'
            '"question":"Hello?",'
            '"options":["Hi","Bye"],'
            '"correct_index":0'
            '}',
        source: TaskSource.cached.storageValue,
        createdAt: DateTime.utc(2026),
      );
      expect(eval.evaluate(task, '{"index":0}').correct, isTrue);
      expect(eval.evaluate(task, '{"index":1}').correct, isFalse);
    });
  });
}
