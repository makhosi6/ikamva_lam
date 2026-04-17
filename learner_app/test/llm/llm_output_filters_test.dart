import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/llm_output_filters.dart';

void main() {
  test('takeThroughFirstBalancedJson trims trailing prose', () {
    const raw = 'noise {"a":1} trailing';
    expect(LlmOutputFilters.takeThroughFirstBalancedJson(raw), '{"a":1}');
  });

  test('nested braces', () {
    const raw = '{"x":{"y":1}}';
    expect(LlmOutputFilters.takeThroughFirstBalancedJson(raw), raw);
  });
}
