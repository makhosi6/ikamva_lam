import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/tasks/cloze_payload.dart';
import 'package:ikamva_lam/game/answer_normalisation_service.dart';

void main() {
  test('matchingClozeOption maps canonical to option chip', () {
    final p = ClozePayload(
      sentence: 'I ___ .',
      answer: 'run',
      options: const ['run', 'walk', 'sit', 'eat'],
    );
    expect(
      AnswerNormalisationService.matchingClozeOption(
        payload: p,
        canonical: 'RUN',
      ),
      'run',
    );
    expect(
      AnswerNormalisationService.matchingClozeOption(
        payload: p,
        canonical: 'walk',
      ),
      'walk',
    );
    expect(
      AnswerNormalisationService.matchingClozeOption(
        payload: p,
        canonical: 'unknown',
      ),
      isNull,
    );
  });
}
