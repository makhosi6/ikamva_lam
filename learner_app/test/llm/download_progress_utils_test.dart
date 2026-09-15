// Feature: model-download-cache, Property 6: Progress values are in range [0, 100]
//
// Validates: Requirements 5.1, 6.1
//
// For any download invocation, every value emitted via onProgress must be in
// the closed interval [0, 100].  This test verifies that [normalizeHfPercent]
// — the function used to normalise raw progress values before emitting them —
// always produces a result in [0, 100].

import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/download_progress_utils.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Unit tests — specific examples
  // ---------------------------------------------------------------------------

  group('normalizeHfPercent — NaN and Infinity return 0', () {
    test('NaN returns 0', () {
      expect(normalizeHfPercent(double.nan), equals(0.0));
    });

    test('positive Infinity returns 0', () {
      expect(normalizeHfPercent(double.infinity), equals(0.0));
    });

    test('negative Infinity returns 0', () {
      expect(normalizeHfPercent(double.negativeInfinity), equals(0.0));
    });
  });

  group('normalizeHfPercent — fractions in (0, 1) are multiplied by 100', () {
    test('0.5 → 50.0', () {
      expect(normalizeHfPercent(0.5), closeTo(50.0, 1e-9));
    });

    test('0.1 → 10.0', () {
      expect(normalizeHfPercent(0.1), closeTo(10.0, 1e-9));
    });

    test('0.99 → 99.0', () {
      expect(normalizeHfPercent(0.99), closeTo(99.0, 1e-9));
    });

    test('very small positive fraction (0.001) → 0.1', () {
      expect(normalizeHfPercent(0.001), closeTo(0.1, 1e-9));
    });

    // Strict < 1: the value 1 is NOT treated as a fraction.
    test('1.0 is treated as 1% (not 100%)', () {
      expect(normalizeHfPercent(1.0), closeTo(1.0, 1e-9));
    });
  });

  group('normalizeHfPercent — values ≥ 1 are used as-is, clamped to 100', () {
    test('50.0 → 50.0', () {
      expect(normalizeHfPercent(50.0), closeTo(50.0, 1e-9));
    });

    test('100.0 → 100.0', () {
      expect(normalizeHfPercent(100.0), closeTo(100.0, 1e-9));
    });

    test('150.0 is clamped to 100.0', () {
      expect(normalizeHfPercent(150.0), closeTo(100.0, 1e-9));
    });

    test('1000.0 is clamped to 100.0', () {
      expect(normalizeHfPercent(1000.0), closeTo(100.0, 1e-9));
    });
  });

  group('normalizeHfPercent — zero and negative values', () {
    test('0.0 → 0.0 (not treated as fraction because p > 0 is required)', () {
      expect(normalizeHfPercent(0.0), closeTo(0.0, 1e-9));
    });

    test('-1.0 is clamped to 0.0', () {
      expect(normalizeHfPercent(-1.0), closeTo(0.0, 1e-9));
    });

    test('-0.5 is clamped to 0.0', () {
      expect(normalizeHfPercent(-0.5), closeTo(0.0, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Property 6: Progress values are in range [0, 100]
  // Feature: model-download-cache, Property 6: Progress values are in range [0, 100]
  //
  // For any input value, normalizeHfPercent must return a value in [0, 100].
  // Validates: Requirements 5.1, 6.1
  // ---------------------------------------------------------------------------

  group('Property 6: Progress values are in range [0, 100]', () {
    // Representative set of raw inputs that cover all branches of the function.
    // The input space is small and enumerable, so we iterate over a curated set
    // rather than using a separate PBT library.
    const rawInputs = <double>[
      // Fractions (0, 1)
      0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999,
      // Boundary: 0 and 1
      0.0, 1.0,
      // Integer-style percentages
      1.0, 10.0, 25.0, 50.0, 75.0, 99.0, 100.0,
      // Over-range
      100.1, 101.0, 200.0, 1000.0,
      // Negative
      -0.001, -1.0, -100.0,
      // Special
      double.nan, double.infinity, double.negativeInfinity,
    ];

    for (final raw in rawInputs) {
      test('normalizeHfPercent($raw) is in [0, 100]', () {
        // Feature: model-download-cache, Property 6: Progress values are in range [0, 100]
        final result = normalizeHfPercent(raw);
        expect(
          result,
          inInclusiveRange(0.0, 100.0),
          reason:
              'normalizeHfPercent($raw) returned $result, which is outside [0, 100]',
        );
      });
    }
  });
}
