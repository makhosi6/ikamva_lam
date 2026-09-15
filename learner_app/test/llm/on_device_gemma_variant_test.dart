import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/on_device_gemma_variant.dart';

void main() {
  test('parses current and legacy variant names', () {
    expect(
      onDeviceGemmaVariantFromName('gemma3nE2b'),
      OnDeviceGemmaVariant.gemma3nE2b,
    );
    expect(
      onDeviceGemmaVariantFromName('e2bHuggingFace'),
      OnDeviceGemmaVariant.gemma4E2b,
    );
    expect(
      onDeviceGemmaVariantFromName('e4bNetwork'),
      OnDeviceGemmaVariant.gemma4E4b,
    );
    expect(
      onDeviceGemmaVariantFromName('e2bBundled'),
      OnDeviceGemmaVariant.gemma4E2b,
    );
    expect(onDeviceGemmaVariantFromName(null), isNull);
    expect(onDeviceGemmaVariantFromName('nope'), isNull);
  });

  test('Gemma 3n requires HF auth; Gemma 4 litert-community does not', () {
    expect(onDeviceGemmaVariantNeedsAuth(OnDeviceGemmaVariant.gemma3nE2b), isTrue);
    expect(onDeviceGemmaVariantNeedsAuth(OnDeviceGemmaVariant.gemma3nE4b), isTrue);
    expect(onDeviceGemmaVariantNeedsAuth(OnDeviceGemmaVariant.gemma4E2b), isFalse);
    expect(onDeviceGemmaVariantNeedsAuth(OnDeviceGemmaVariant.gemma4E4b), isFalse);
  });

  test('labels are non-empty for every variant', () {
    for (final v in OnDeviceGemmaVariant.values) {
      expect(onDeviceGemmaVariantLabel(v), isNotEmpty);
    }
  });
}
