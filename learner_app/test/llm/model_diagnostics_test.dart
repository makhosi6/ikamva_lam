import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/model_diagnostics.dart';

void main() {
  setUp(() {
    ModelDiagnostics.instance.clear();
  });

  test('log appends event with metadata', () {
    ModelDiagnostics.instance.log(
      area: 'test',
      action: 'sample',
      message: 'hello',
      data: const <String, Object?>{'n': 1},
    );

    final events = ModelDiagnostics.instance.events.value;
    expect(events.length, 1);
    expect(events.single.area, 'test');
    expect(events.single.action, 'sample');
    expect(events.single.message, 'hello');
    expect(events.single.data['n'], 1);
  });

  test('asPrettyJson returns valid JSON array', () {
    ModelDiagnostics.instance.log(
      area: 'test',
      action: 'sample',
      message: 'hello',
    );

    final text = ModelDiagnostics.instance.asPrettyJson();
    final decoded = jsonDecode(text);
    expect(decoded, isA<List<dynamic>>());
    expect((decoded as List<dynamic>).length, 1);
  });
}
