import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/prompts/slot_substitution.dart';

void main() {
  test('applyPromptSlots replaces all keys', () {
    const t = '{{A}} {{B}}';
    expect(
      applyPromptSlots(t, {'A': 'x', 'B': 'y'}),
      'x y',
    );
  });
}
