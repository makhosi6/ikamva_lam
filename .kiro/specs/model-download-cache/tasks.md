# Implementation Plan: Model Download Cache

## Overview

Introduce a `ModelCacheChecker` helper, add a cache-first gate to `FlutterGemmaLlmEngine._ensureLoadedBody`, and add tests covering the cache check, fingerprint logic, error classification, and progress normalization. All changes are in `learner_app/lib/llm/` and `learner_app/test/llm/`.

## Tasks

- [x] 1. Add `ModelCacheChecker` helper
  - Create `learner_app/lib/llm/model_cache_checker.dart` with a static `isCached(Gemma4OnDeviceVariant variant)` method.
  - The method must call `GemmaHfModelDownloadService(variant).isPluginModelInstalled()` and `ModelPreparePrefs.shouldPrepareForFingerprint(ModelPrepareConfig.installFingerprint(variant))`.
  - Return `true` only when the file exists AND the fingerprint matches (i.e., `isInstalled && !shouldPrepare`).
  - No network calls — file-system only.
  - _Requirements: 1.1, 1.2, 1.5_

  - [x] 1.1 Write unit tests for `ModelCacheChecker`
    - Test: file absent → `isCached` returns `false` (mock `isPluginModelInstalled` = false).
    - Test: file present but fingerprint mismatch → `isCached` returns `false`.
    - Test: file present and fingerprint matches → `isCached` returns `true`.
    - **Property 8: isCached is false when file absent**
    - **Property 9: isCached is false when fingerprint mismatches**
    - **Validates: Requirements 1.1, 1.4, 1.5**

- [x] 2. Add cache-first gate to `FlutterGemmaLlmEngine._ensureLoadedBody`
  - At the top of `_ensureLoadedBody` (after the disposed/platform checks), call `ModelCacheChecker.isCached(_settings.gemma4OnDeviceVariant)`.
  - If `true`: emit `'open'` lifecycle event with "Model found in storage — opening…" and skip `_installFromConfiguredSource`.
  - If `false`: call `_installFromConfiguredSource` as before.
  - The existing open / retry / purge / reinstall logic below the gate is unchanged.
  - _Requirements: 1.2, 1.3, 2.1_

  - [x] 2.1 Write unit tests for the cache gate in `FlutterGemmaLlmEngine`
    - On non-mobile host, `ensureLoaded` throws `LlmUnavailableException` (existing test, verify still passes).
    - **Property 1: Cache hit skips download**
    - **Property 2: Cache miss triggers install**
    - **Validates: Requirements 1.2, 1.3, 2.1**

- [x] 3. Extend `ModelPreparePrefs` tests
  - Add tests to `learner_app/test/llm/model_prepare_prefs_test.dart` covering:
    - `shouldPrepareForFingerprint` returns `true` when a different fingerprint is stored.
    - `shouldPrepareForFingerprint` returns `false` after `markPrepareDone` with the same fingerprint (all variants).
    - `clearPrepareDone` resets done, fingerprint, and timestamp for all variants.
  - **Property 3: Fingerprint round-trip**
  - **Property 4: Clear resets all prefs fields**
  - **Property 5: Distinct fingerprints per variant**
  - _Requirements: 3.2, 3.3, 3.4, 6.2, 6.3_

- [x] 4. Checkpoint — Ensure all tests pass
  - Run `flutter test learner_app/test/llm/` and confirm all tests pass.
  - Ask the user if any questions arise.

- [x] 5. Add `GemmaHfModelDownloadService` and error-classification tests
  - Add tests to `learner_app/test/llm/` covering:
    - `GemmaHfModelDownloadService.isPluginModelInstalled` returns `false` on non-mobile (kIsWeb guard and non-mobile host).
    - `gemmaErrorLooksLikeGpuResourceExhaustion` correctly classifies known GPU exhaustion strings.
    - Storage error strings trigger `LlmResourceException` (verify the `msg.contains('space')` / `'storage'` / `'enospc'` branches in `_installFromHfService`).
  - _Requirements: 5.2, 5.4, 6.4, 6.5_

  - [x] 5.1 Write property test for error classification
    - **Property (error classification): For all known GPU-exhaustion error strings, `gemmaErrorLooksLikeGpuResourceExhaustion` returns `true`; for all known non-GPU strings, it returns `false`.**
    - **Validates: Requirements 6.5**

- [x] 6. Add progress normalization test
  - In `learner_app/test/llm/`, add a test that verifies the `_normalizeHfPercent` logic (or equivalent) clamps all values to [0, 100].
  - Cover: values in (0, 1) are treated as fractions and multiplied by 100; values ≥ 1 are used as-is clamped to 100; NaN and Infinity return 0.
  - **Property 6: Progress values are in range [0, 100]**
  - _Requirements: 5.1, 6.1_

- [x] 7. Final checkpoint — Ensure all tests pass
  - Run `flutter test learner_app/test/llm/` and confirm all tests pass.
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP.
- The cache gate (Task 2) is the highest-value change: it eliminates redundant download attempts on every warm-up.
- `ModelCacheChecker` (Task 1) is a pure composition of existing APIs — no new persistence or network code.
- All test files live under `learner_app/test/llm/` to match the existing test layout.
- Use `SharedPreferences.setMockInitialValues({})` in `setUp` for all prefs tests (existing pattern).
- The `_normalizeHfPercent` function is currently private to `_GemmaSetupScreenState`; if needed, extract it to a testable location in `learner_app/lib/llm/` (e.g., `gemma_hf_model_download_service.dart` or a new `download_progress_utils.dart`).
