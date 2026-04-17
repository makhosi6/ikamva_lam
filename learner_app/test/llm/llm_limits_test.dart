import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/llm_limits.dart';

void main() {
  test('clampContext low vs standard defaults', () {
    expect(LlmLimits.clampContext(0, lowRamProfile: false), 768);
    expect(LlmLimits.clampContext(0, lowRamProfile: true), 512);
    expect(LlmLimits.clampContext(2000, lowRamProfile: false), 1024);
    expect(LlmLimits.clampContext(400, lowRamProfile: false), 512);
  });

  test('clampMaxNewTokens', () {
    expect(LlmLimits.clampMaxNewTokens(0), LlmLimits.defaultMaxNewTokens);
    expect(LlmLimits.clampMaxNewTokens(999), 256);
  });
}
