import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/flutter_gemma_llm_engine.dart';

void main() {
  test('detects GPU delegate failures', () {
    expect(
      gemmaErrorLooksLikeGpuMetalDelegateFailure(
        Exception('Failed in ModifyGraphWithDelegate: tfliteGpuDelegate'),
      ),
      isTrue,
    );
  });

  test('detects invalid archive errors but not GPU errors', () {
    expect(
      gemmaErrorLooksLikeInvalidTaskArchive(
        Exception('Unable to open zip archive from downloaded task file'),
      ),
      isTrue,
    );
    expect(
      gemmaErrorLooksLikeInvalidTaskArchive(
        Exception('Failed in ModifyGraphWithDelegate: tfliteGpuDelegate'),
      ),
      isFalse,
    );
  });
}
