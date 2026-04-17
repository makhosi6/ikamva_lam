import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/task_type.dart';
import 'package:ikamva_lam/prompts/prompt_composer.dart';
import 'package:ikamva_lam/prompts/prompt_slots.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('composeGenerationPrompt loads bundled prompt_v3 assets', () async {
    const slots = PromptSlots(
      level: 'A1',
      topic: 'food',
      skill: 'vocabulary',
      difficultyStep: '2',
    );
    final c = PromptComposer();
    final p = await c.composeGenerationPrompt(TaskType.cloze, slots);
    expect(p, contains('TASK: generate_cloze'));
    expect(p, contains('OUTPUT JSON ONLY'));
    expect(p, contains('If you cannot comply'));
    expect(p, contains('Egg, bread')); // topic_vocab line for food
    expect(p, contains('LEVEL: A1'));
  });

  test('composeHintPrompt and insight include JSON-only rules', () async {
    final c = PromptComposer();
    final h = await c.composeHintPrompt(
      taskJson: '{"x":1}',
      wrongAnswer: 'bad',
    );
    expect(h, contains('hint_en'));
    final i = await c.composeInsightPrompt('{"errors":1}');
    expect(i, contains('recommendation'));
  });

  test('composeNormaliseAnswerPrompt asset present', () async {
    final c = PromptComposer();
    final n = await c.composeNormaliseAnswerPrompt(
      taskJson: '{}',
      learnerText: 'ndiyathanda',
    );
    expect(n, contains('canonical_en'));
  });
}
