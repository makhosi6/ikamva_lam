# Requirements Document

## Introduction

The learner app uses on-device Gemma 4 inference via `flutter_gemma` / LiteRT-LM. Model weights (~2.4–4.4 GB) are downloaded from Hugging Face to app documents storage. Currently, the download check (`checkModelExistence`) makes an HTTP HEAD request on every app launch, the cache-hit fast path is not consistently exercised before triggering a re-download, and the `ensureLoaded` flow in `FlutterGemmaLlmEngine` always calls `_installFromConfiguredSource` even when the file is already on disk and valid. This feature tightens the download-and-load flow so that:

1. A model already present in local storage is **never re-downloaded**.
2. The model is opened as fast as possible on subsequent launches (no redundant I/O or network calls).
3. The cache state is persisted reliably across cold starts and variant switches.
4. The flow is covered by automated tests to prevent regressions.

## Glossary

- **ModelCacheChecker**: Component responsible for determining whether a valid model file exists in local storage without making network requests.
- **GemmaHfModelDownloadService**: Existing service that downloads `.litertlm` weights from Hugging Face and writes them to app documents.
- **FlutterGemmaLlmEngine**: Existing engine that installs and opens the model via native MethodChannel (LiteRT-LM / MediaPipe).
- **ModelPreparePrefs**: Existing SharedPreferences wrapper that persists the install fingerprint and done flag.
- **ModelPrepareConfig**: Existing class providing fingerprints, size estimates, and context token limits.
- **Install fingerprint**: A stable string that uniquely identifies a model variant and its source URL; used to detect when the cached model is stale.
- **Variant**: One of `Gemma4OnDeviceVariant.e2bHuggingFace` or `Gemma4OnDeviceVariant.e4bNetwork`.
- **Cache hit**: The model file exists on disk, its size matches expectations, and the stored fingerprint matches the active variant.
- **Cache miss**: The model file is absent, zero-length, or the fingerprint does not match the active variant.

---

## Requirements

### Requirement 1: Local Cache Check Before Download

**User Story:** As a learner, I want the app to skip downloading the model when it is already on my device, so that I do not waste mobile data or wait for a redundant download on every launch.

#### Acceptance Criteria

1. WHEN `FlutterGemmaLlmEngine.ensureLoaded` is called, THE `ModelCacheChecker` SHALL check whether the model file exists on disk before initiating any network activity.
2. WHEN the model file exists on disk and the stored install fingerprint matches the active variant, THE `FlutterGemmaLlmEngine` SHALL skip the download step entirely and proceed directly to opening the model.
3. WHEN the model file does not exist on disk, THE `FlutterGemmaLlmEngine` SHALL initiate the download from the configured Hugging Face URL.
4. WHEN the stored install fingerprint does not match the active variant, THE `FlutterGemmaLlmEngine` SHALL purge the stale file and initiate a fresh download for the new variant.
5. THE `ModelCacheChecker` SHALL determine file existence using only local file-system operations, with no HTTP requests.

### Requirement 2: Fast Model Loading from Storage

**User Story:** As a learner, I want the model to load quickly on subsequent launches, so that I can start practising without a long wait after the first setup.

#### Acceptance Criteria

1. WHEN the model file is confirmed present on disk and the fingerprint matches, THE `FlutterGemmaLlmEngine` SHALL open the model via the native channel without re-copying or re-downloading the file.
2. WHEN `ModelPreparePrefs.isPrepareDone` returns `true` and the fingerprint matches the active variant, THE `LlmService` SHALL proceed to `ensureLoaded` without resetting the prepare state.
3. WHEN the native model open succeeds on the first attempt, THE `FlutterGemmaLlmEngine` SHALL mark `_loaded = true` and emit the `ready` lifecycle event within the same call.
4. WHEN `FlutterGemmaLlmEngine.ensureLoaded` is called concurrently from multiple callers, THE engine SHALL deduplicate the load into a single in-flight `Future` so the native model is opened exactly once.

### Requirement 3: Cache Invalidation on Variant Switch

**User Story:** As a learner, I want switching between E2B and E4B models to work correctly, so that I always run the model I selected without stale files causing errors.

#### Acceptance Criteria

1. WHEN the user selects a different `Gemma4OnDeviceVariant` in the setup screen, THE `GemmaSetupScreen` SHALL call `purgeGemmaPluginInstallCandidates` and `ModelPreparePrefs.clearPrepareDone` before persisting the new variant.
2. WHEN `ModelPreparePrefs.shouldPrepareForFingerprint` is called with a fingerprint that differs from the stored one, THE `ModelPreparePrefs` SHALL return `true`.
3. WHEN `ModelPreparePrefs.shouldPrepareForFingerprint` is called with a fingerprint that matches the stored one and `isPrepareDone` is `true`, THE `ModelPreparePrefs` SHALL return `false`.
4. WHEN `ModelPreparePrefs.clearPrepareDone` is called, THE `ModelPreparePrefs` SHALL remove the done flag, fingerprint, and timestamp from persistent storage.

### Requirement 4: Resilient Cache State Persistence

**User Story:** As a learner, I want the app to remember that the model is ready across cold starts, so that I do not have to wait for a re-check every time I open the app.

#### Acceptance Criteria

1. WHEN `FlutterGemmaLlmEngine._finishLoaded` is called after a successful native open, THE engine SHALL persist the install fingerprint via `ModelPreparePrefs.markPrepareDone`.
2. WHEN the app cold-starts and `ModelPreparePrefs.isPrepareDone` returns `true` with a matching fingerprint, THE `LlmService` SHALL not trigger a re-download or re-install.
3. IF `ModelPreparePrefs.markPrepareDone` throws an exception, THEN THE engine SHALL log the error and continue without crashing (best-effort persistence).
4. WHEN `LlmService.invalidateCachedEngine` is called, THE `LlmService` SHALL set `onDeviceWeightsReady` to `false` and dispose the cached engine, but SHALL NOT clear the on-disk model file or the prepare prefs.

### Requirement 5: Download Progress and Error Reporting

**User Story:** As a learner, I want clear feedback during a download and actionable error messages when something goes wrong, so that I know what is happening and what to do next.

#### Acceptance Criteria

1. WHEN a download is in progress, THE `GemmaHfModelDownloadService` SHALL emit integer progress values in the range [0, 100] via the `onProgress` callback.
2. WHEN a download fails due to insufficient storage, THE `FlutterGemmaLlmEngine` SHALL throw `LlmResourceException` with a message that mentions storage.
3. WHEN a download fails due to a network error after all retries are exhausted, THE `FlutterGemmaLlmEngine` SHALL throw `LlmUnavailableException` with a descriptive message.
4. WHEN `GemmaHfModelDownloadService.isPluginModelInstalled` is called on a web platform, THE service SHALL return `false` without accessing the file system.

### Requirement 6: Test Coverage for Download and Cache Flow

**User Story:** As a developer, I want automated tests for the download-and-cache flow, so that regressions in cache checks, fingerprint logic, and error handling are caught before release.

#### Acceptance Criteria

1. THE test suite SHALL include unit tests that verify `ModelCacheChecker` returns `true` when the model file exists and `false` when it does not, without making network requests.
2. THE test suite SHALL include unit tests that verify `ModelPreparePrefs` correctly stores, retrieves, and clears the done flag, fingerprint, and timestamp.
3. THE test suite SHALL include unit tests that verify `ModelPreparePrefs.shouldPrepareForFingerprint` returns `true` for a new fingerprint and `false` for a matching fingerprint after `markPrepareDone`.
4. THE test suite SHALL include unit tests that verify `GemmaHfModelDownloadService.isPluginModelInstalled` returns `false` on non-mobile platforms.
5. THE test suite SHALL include unit tests that verify `FlutterGemmaLlmEngine` error-classification helpers (`gemmaErrorLooksLikeInvalidTaskArchive`, `gemmaErrorLooksLikeGpuMetalDelegateFailure`, `gemmaErrorLooksLikeGpuResourceExhaustion`) correctly classify known error strings.
6. THE test suite SHALL include unit tests that verify `ModelPrepareConfig.installFingerprint` returns distinct values for each `Gemma4OnDeviceVariant`.
