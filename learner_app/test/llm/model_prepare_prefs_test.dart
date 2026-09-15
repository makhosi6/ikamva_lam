import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/on_device_gemma_variant.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/llm/model_prepare_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ---------------------------------------------------------------------------
  // Existing tests
  // ---------------------------------------------------------------------------

  test('shouldPrepareForFingerprint is true when no prepare state', () async {
    final fp = ModelPrepareConfig.installFingerprint(
      OnDeviceGemmaVariant.gemma4E2b,
    );
    final shouldPrepare = await ModelPreparePrefs.shouldPrepareForFingerprint(fp);
    expect(shouldPrepare, isTrue);
  });

  test('markPrepareDone records done/fingerprint/timestamp', () async {
    final fp = ModelPrepareConfig.installFingerprint(
      OnDeviceGemmaVariant.gemma4E2b,
    );
    await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

    expect(await ModelPreparePrefs.isPrepareDone(), isTrue);
    expect(
      await ModelPreparePrefs.preparedInstallFingerprint(),
      fp,
    );
    expect(await ModelPreparePrefs.preparedAt(), isNotNull);
  });

  test('clearPrepareDone removes done/fingerprint/timestamp', () async {
    final fp = ModelPrepareConfig.installFingerprint(
      OnDeviceGemmaVariant.gemma4E4b,
    );
    await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);
    await ModelPreparePrefs.clearPrepareDone();

    expect(await ModelPreparePrefs.isPrepareDone(), isFalse);
    expect(await ModelPreparePrefs.preparedInstallFingerprint(), isNull);
    expect(await ModelPreparePrefs.preparedAt(), isNull);
  });

  // ---------------------------------------------------------------------------
  // New unit tests — shouldPrepareForFingerprint with a different fingerprint
  // ---------------------------------------------------------------------------

  test(
    'shouldPrepareForFingerprint returns true when a different fingerprint is stored',
    () async {
      // Mark done with the E2B fingerprint.
      final e2bFp = ModelPrepareConfig.installFingerprint(
        OnDeviceGemmaVariant.gemma4E2b,
      );
      await ModelPreparePrefs.markPrepareDone(installFingerprint: e2bFp);

      // Asking for the E4B fingerprint should return true (mismatch).
      final e4bFp = ModelPrepareConfig.installFingerprint(
        OnDeviceGemmaVariant.gemma4E4b,
      );
      expect(
        await ModelPreparePrefs.shouldPrepareForFingerprint(e4bFp),
        isTrue,
      );
    },
  );

  test(
    'shouldPrepareForFingerprint returns true when an arbitrary different fingerprint is stored',
    () async {
      const storedFp = 'network:https://example.com/old-model.litertlm';
      const queriedFp = 'network:https://example.com/new-model.litertlm';
      await ModelPreparePrefs.markPrepareDone(installFingerprint: storedFp);

      expect(
        await ModelPreparePrefs.shouldPrepareForFingerprint(queriedFp),
        isTrue,
      );
    },
  );

  // ---------------------------------------------------------------------------
  // New unit tests — shouldPrepareForFingerprint returns false after
  // markPrepareDone with the same fingerprint (all variants)
  // ---------------------------------------------------------------------------

  for (final variant in OnDeviceGemmaVariant.values) {
    test(
      'shouldPrepareForFingerprint returns false after markPrepareDone '
      'with same fingerprint — variant ${variant.name}',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final fp = ModelPrepareConfig.installFingerprint(variant);
        await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

        expect(
          await ModelPreparePrefs.shouldPrepareForFingerprint(fp),
          isFalse,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // New unit tests — clearPrepareDone resets all fields for all variants
  // ---------------------------------------------------------------------------

  for (final variant in OnDeviceGemmaVariant.values) {
    test(
      'clearPrepareDone resets done, fingerprint, and timestamp '
      '— variant ${variant.name}',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final fp = ModelPrepareConfig.installFingerprint(variant);
        await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

        // Verify state was written before clearing.
        expect(await ModelPreparePrefs.isPrepareDone(), isTrue);

        await ModelPreparePrefs.clearPrepareDone();

        expect(await ModelPreparePrefs.isPrepareDone(), isFalse);
        expect(await ModelPreparePrefs.preparedInstallFingerprint(), isNull);
        expect(await ModelPreparePrefs.preparedAt(), isNull);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Property 3: Fingerprint round-trip
  // Feature: model-download-cache, Property 3: Fingerprint round-trip
  //
  // For any OnDeviceGemmaVariant, calling markPrepareDone(installFingerprint: fp)
  // followed by shouldPrepareForFingerprint(fp) must return false.
  // Validates: Requirements 3.2, 3.3, 4.1
  // ---------------------------------------------------------------------------

  group('Property 3: Fingerprint round-trip', () {
    for (final variant in OnDeviceGemmaVariant.values) {
      test('variant ${variant.name}', () async {
        // Feature: model-download-cache, Property 3: Fingerprint round-trip
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final fp = ModelPrepareConfig.installFingerprint(variant);

        await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

        // After marking done with the same fingerprint, shouldPrepare must be false.
        expect(
          await ModelPreparePrefs.shouldPrepareForFingerprint(fp),
          isFalse,
          reason:
              'shouldPrepareForFingerprint must return false after '
              'markPrepareDone with the same fingerprint (variant: ${variant.name})',
        );
      });
    }

    // Also verify with arbitrary fingerprint strings to cover the general case.
    const arbitraryFingerprints = [
      'network:https://huggingface.co/model-a.litertlm',
      'network:https://huggingface.co/model-b.litertlm',
      'network:https://example.com/weights.bin',
      'asset:bundled/model.task',
      'network:https://cdn.example.org/v2/gemma.litertlm',
    ];

    for (final fp in arbitraryFingerprints) {
      test('arbitrary fingerprint "$fp"', () async {
        // Feature: model-download-cache, Property 3: Fingerprint round-trip
        SharedPreferences.setMockInitialValues(<String, Object>{});

        await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

        expect(
          await ModelPreparePrefs.shouldPrepareForFingerprint(fp),
          isFalse,
          reason:
              'shouldPrepareForFingerprint must return false after '
              'markPrepareDone with the same fingerprint',
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Property 4: Clear resets all prefs fields
  // Feature: model-download-cache, Property 4: Clear resets all prefs fields
  //
  // For any state where markPrepareDone has been called, calling clearPrepareDone
  // must result in isPrepareDone() == false, preparedInstallFingerprint() == null,
  // and preparedAt() == null.
  // Validates: Requirements 3.4
  // ---------------------------------------------------------------------------

  group('Property 4: Clear resets all prefs fields', () {
    for (final variant in OnDeviceGemmaVariant.values) {
      test('variant ${variant.name}', () async {
        // Feature: model-download-cache, Property 4: Clear resets all prefs fields
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final fp = ModelPrepareConfig.installFingerprint(variant);

        await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);
        await ModelPreparePrefs.clearPrepareDone();

        expect(
          await ModelPreparePrefs.isPrepareDone(),
          isFalse,
          reason: 'isPrepareDone must be false after clearPrepareDone',
        );
        expect(
          await ModelPreparePrefs.preparedInstallFingerprint(),
          isNull,
          reason: 'preparedInstallFingerprint must be null after clearPrepareDone',
        );
        expect(
          await ModelPreparePrefs.preparedAt(),
          isNull,
          reason: 'preparedAt must be null after clearPrepareDone',
        );
      });
    }

    // Also verify that clearPrepareDone works even when called without a prior
    // markPrepareDone (idempotent clear).
    test('clearPrepareDone is idempotent on empty prefs', () async {
      // Feature: model-download-cache, Property 4: Clear resets all prefs fields
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await ModelPreparePrefs.clearPrepareDone();

      expect(await ModelPreparePrefs.isPrepareDone(), isFalse);
      expect(await ModelPreparePrefs.preparedInstallFingerprint(), isNull);
      expect(await ModelPreparePrefs.preparedAt(), isNull);
    });

    // Verify that shouldPrepareForFingerprint returns true after clear.
    for (final variant in OnDeviceGemmaVariant.values) {
      test(
        'shouldPrepareForFingerprint returns true after clearPrepareDone '
        '— variant ${variant.name}',
        () async {
          // Feature: model-download-cache, Property 4: Clear resets all prefs fields
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final fp = ModelPrepareConfig.installFingerprint(variant);

          await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);
          await ModelPreparePrefs.clearPrepareDone();

          expect(
            await ModelPreparePrefs.shouldPrepareForFingerprint(fp),
            isTrue,
            reason:
                'shouldPrepareForFingerprint must return true after '
                'clearPrepareDone (variant: ${variant.name})',
          );
        },
      );
    }
  });

  // ---------------------------------------------------------------------------
  // Property 5: Distinct fingerprints per variant
  // Feature: model-download-cache, Property 5: Distinct fingerprints per variant
  //
  // For all pairs of distinct OnDeviceGemmaVariant values,
  // ModelPrepareConfig.installFingerprint(v1) != ModelPrepareConfig.installFingerprint(v2).
  // Validates: Requirements 3.2, 6.3
  // ---------------------------------------------------------------------------

  test('Property 5: Distinct fingerprints per variant', () {
    // Feature: model-download-cache, Property 5: Distinct fingerprints per variant
    final variants = OnDeviceGemmaVariant.values;
    final fingerprints = variants
        .map((v) => ModelPrepareConfig.installFingerprint(v))
        .toList();

    // All fingerprints must be unique.
    final uniqueFingerprints = fingerprints.toSet();
    expect(
      uniqueFingerprints.length,
      equals(variants.length),
      reason:
          'Each OnDeviceGemmaVariant must produce a distinct installFingerprint. '
          'Got: $fingerprints',
    );

    // Verify each pair explicitly for clarity.
    for (var i = 0; i < variants.length; i++) {
      for (var j = i + 1; j < variants.length; j++) {
        expect(
          fingerprints[i],
          isNot(equals(fingerprints[j])),
          reason:
              'installFingerprint(${variants[i].name}) must differ from '
              'installFingerprint(${variants[j].name})',
        );
      }
    }
  });
}
