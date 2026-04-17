import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/game/adaptive_difficulty_engine.dart';

void main() {
  const engine = AdaptiveDifficultyEngine();

  test('high rolling accuracy increases step when below cap', () {
    final adj = engine.recommend(
      rollingAccuracy: 0.95,
      currentStep: 1,
      maxStep: 3,
      hintFirstActive: false,
    );
    expect(adj, DifficultyAdjustment.harder);
    final next = engine.apply(
      adjustment: adj,
      currentStep: 1,
      hintFirstMode: false,
      maxStep: 3,
    );
    expect(next.step, 2);
    expect(next.hintFirstMode, isFalse);
  });

  test('at max step high accuracy holds', () {
    final adj = engine.recommend(
      rollingAccuracy: 1,
      currentStep: 3,
      maxStep: 3,
      hintFirstActive: false,
    );
    expect(adj, DifficultyAdjustment.hold);
  });

  test('low rolling accuracy decreases step when above 1', () {
    final adj = engine.recommend(
      rollingAccuracy: 0.2,
      currentStep: 2,
      maxStep: 3,
      hintFirstActive: false,
    );
    expect(adj, DifficultyAdjustment.easier);
    final next = engine.apply(
      adjustment: adj,
      currentStep: 2,
      hintFirstMode: false,
      maxStep: 3,
    );
    expect(next.step, 1);
  });

  test('low rolling at min step enables hint-first once', () {
    final adj = engine.recommend(
      rollingAccuracy: 0.1,
      currentStep: 1,
      maxStep: 3,
      hintFirstActive: false,
    );
    expect(adj, DifficultyAdjustment.enableHintFirst);
    final next = engine.apply(
      adjustment: adj,
      currentStep: 1,
      hintFirstMode: false,
      maxStep: 3,
    );
    expect(next.step, 1);
    expect(next.hintFirstMode, isTrue);
  });

  test('simulated streak: easy → hard → cap holds', () {
    var step = 1;
    const max = 3;
    var hint = false;
    for (final acc in [0.9, 0.85, 0.9]) {
      final adj = engine.recommend(
        rollingAccuracy: acc,
        currentStep: step,
        maxStep: max,
        hintFirstActive: hint,
      );
      final next = engine.apply(
        adjustment: adj,
        currentStep: step,
        hintFirstMode: hint,
        maxStep: max,
      );
      step = next.step;
      hint = next.hintFirstMode;
    }
    expect(step, 3);
    final last = engine.recommend(
      rollingAccuracy: 0.99,
      currentStep: step,
      maxStep: max,
      hintFirstActive: hint,
    );
    expect(last, DifficultyAdjustment.hold);
  });
}
