import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/domain/difficulty/difficulty_state.dart';

void main() {
  test('DifficultyState captures skill strand view', () {
    const s = DifficultyState(
      skillId: 'vocabulary',
      step: 2,
      maxStep: 3,
      hintFirstMode: true,
    );
    expect(s.step, 2);
    expect(s.maxStep, 3);
    expect(s.hintFirstMode, isTrue);
  });
}
