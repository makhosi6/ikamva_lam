import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/prompts/prompt_compliance.dart';

void main() {
  test('detects empty object', () {
    expect(isEmptyComplianceObject('{}'), true);
    expect(isEmptyComplianceObject('  {\n}  '), true);
    expect(isEmptyComplianceObject('prefix {} suffix'), true);
    expect(isEmptyComplianceObject('{"a":1}'), false);
    expect(isEmptyComplianceObject(''), true);
  });
}
