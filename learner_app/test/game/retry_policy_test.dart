import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/game/retry_policy.dart';

void main() {
  test('PerTaskRetryPolicy allows maxRetries + 1 submissions', () {
    final p = PerTaskRetryPolicy(maxRetries: 2);
    expect(p.canSubmit, isTrue);
    p.recordSubmission();
    expect(p.canSubmit, isTrue);
    p.recordSubmission();
    expect(p.canSubmit, isTrue);
    p.recordSubmission();
    expect(p.canSubmit, isFalse);
  });

  test('resetForNewTask clears counter', () {
    final p = PerTaskRetryPolicy(maxRetries: 0);
    p.recordSubmission();
    expect(p.canSubmit, isFalse);
    p.resetForNewTask();
    expect(p.canSubmit, isTrue);
  });
}
