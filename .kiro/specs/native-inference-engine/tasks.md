# Implementation Plan: Native Inference Engine

## Overview

Implement the cross-platform (Android, iOS, Huawei) native inference engine by hardening the existing in-tree `NativeLlmBridge` implementations, tightening the Dart `FlutterGemmaLlmEngine` / `NativeLlmPlatform` layer, and adding comprehensive test coverage. The implementation follows the channel protocol defined in the design document.

## Tasks

- [x] 1. Harden Android/Huawei NativeLlmBridge
  - [x] 1.1 Validate `loadModel` arguments and return `bad_args` on missing/wrong-type `modelPath`
    - Add explicit null/type check for `modelPath` before `File(path).exists()` check
    - Return `result.error("bad_args", "missing or invalid modelPath", null)` on failure
    - _Requirements: 2.3_

  - [x] 1.2 Ensure `closeAllEngines` is called before every `loadModel` (idempotent reload)
    - Verify `closeAllEngines()` is the first call in `handleLoad` — already present; add test coverage
    - _Requirements: 2.2_

  - [x] 1.3 Write property test for sequential loadModel closes previous runtime
    - **Property 3: Sequential loadModel calls close the previous runtime**
    - **Validates: Requirements 2.2**
    - Use mock `Engine`/`LlmInference` to verify close is called before open on second load

  - [x] 1.4 Add per-session `finally` close for `Conversation` and `LlmInferenceSession`
    - Verify `conversation.close()` and `session.close()` are in `finally` blocks in all generate/stream paths
    - _Requirements: 5.5_

  - [x] 1.5 Write unit test for generate-with-no-model returns generate_failed
    - **Property 7 (example): closeModel makes generate fail**
    - **Validates: Requirements 3.2, 5.1**

- [x] 2. Harden iOS NativeLlmBridge
  - [x] 2.1 Validate `loadModel` arguments on iOS — return `bad_args` on missing `modelPath`
    - Add guard for `modelPath` being nil or empty string before `FileManager.fileExists` check
    - _Requirements: 2.3_

  - [x] 2.2 Ensure `closeAll()` is called at the start of `loadModel` (idempotent reload)
    - Verify `closeAll()` is the first call in `loadModel` — already present; add test coverage
    - _Requirements: 2.2_

  - [x] 2.3 Ensure streaming `Task` is cancelled in `onCancel` and no events are sent after cancel
    - Verify `streamingTask?.cancel()` is called and `Task.checkCancellation()` is checked in the stream loop
    - _Requirements: 4.4_

  - [x] 2.4 Write unit test for iOS bad_args and load_failed error codes
    - **Validates: Requirements 2.3, 2.4**

- [x] 3. Checkpoint — Ensure all native bridge tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Harden Dart NativeLlmPlatform and FlutterGemmaLlmEngine
  - [x] 4.1 Verify `NativeLlmPlatform.generateStream` correctly maps Map `token`/`error` events and plain String events
    - Ensure the stream handler covers all three event shapes from the design's EventChannel stream event table
    - _Requirements: 8.3, 8.4_

  - [x] 4.2 Write property test for Dart argument map schema (Property 16)
    - **Property 16: Dart argument map matches channel protocol schema**
    - **Validates: Requirements 8.2**
    - Generate representative `LlmGenerateRequest` values; assert all required keys present with correct types

  - [x] 4.3 Verify `_applyStopSequences` truncates at first occurrence of any stop sequence
    - Confirm existing implementation handles empty stop sequences and multiple stops correctly
    - _Requirements: 7.8_

  - [x] 4.4 Write property test for stop sequence truncation (Property 13)
    - **Property 13: Stop sequences truncate response at first occurrence**
    - **Validates: Requirements 7.8**
    - Generate random response strings and stop sequences; verify truncation position

  - [x] 4.5 Verify `ensureLoaded` single-flight deduplication (`_ensureLoadedInFlight`)
    - Confirm the `_ensureLoadedInFlight ??= _ensureLoadedBody()` pattern is correct and the field is cleared in `finally`
    - _Requirements: 7.4_

  - [x] 4.6 Write property test for ensureLoaded deduplication (Property 12)
    - **Property 12: ensureLoaded deduplicates concurrent calls**
    - **Validates: Requirements 7.4**
    - Call `ensureLoaded` concurrently N times; verify `loadModel` channel is invoked exactly once

  - [x] 4.7 Verify `StateError` is thrown after `dispose` for both `generate` and `generateChunkStream`
    - _Requirements: 7.5_

  - [x] 4.8 Write property test for StateError after dispose (Property 8)
    - **Property 8: FlutterGemmaLlmEngine throws StateError after dispose**
    - **Validates: Requirements 5.4, 7.5**

- [x] 5. Error classification and GPU fallback
  - [x] 5.1 Verify all three error classifier functions cover the documented keyword sets
    - Cross-check `gemmaErrorLooksLikeGpuMetalDelegateFailure`, `gemmaErrorLooksLikeGpuResourceExhaustion`, `gemmaErrorLooksLikeInvalidTaskArchive` against the keyword lists in Requirements 9.1–9.3
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 5.2 Write property test for error classifiers (Property 14)
    - **Property 14: Error classifiers correctly categorise known error strings**
    - **Validates: Requirements 9.1, 9.2, 9.3**
    - Iterate over ≥ 10 known strings per category; verify correct boolean for all combinations
    - Minimum 100 iterations using generated mixed-case and substring variants

  - [x] 5.3 Verify GPU→CPU fallback logic for non-multimodal models in `_openActiveModel`
    - Confirm the fallback path calls `_nativeOpen(preferGpu: false)` when GPU fails and `_multimodalRequiresGpu` is false
    - _Requirements: 6.2_

  - [x] 5.4 Write property test for GPU fallback (Property 9)
    - **Property 9: GPU fallback succeeds for non-multimodal models**
    - **Validates: Requirements 6.2**
    - Mock `NativeLlmPlatform.loadModel` to fail on `preferGpu: true` and succeed on `preferGpu: false`; verify `ensureLoaded` completes

  - [x] 5.5 Verify multimodal GPU failure propagates without CPU fallback
    - Confirm `_multimodalRequiresGpu` guard prevents CPU retry when vision/audio is enabled
    - _Requirements: 6.3_

  - [x] 5.6 Write property test for multimodal GPU failure propagation (Property 10)
    - **Property 10: Multimodal GPU failure propagates without CPU fallback**
    - **Validates: Requirements 6.3**

  - [x] 5.7 Verify `lowRamProfile` forces `preferGpu: false` for non-multimodal models
    - _Requirements: 6.5_

  - [x] 5.8 Write property test for lowRamProfile CPU enforcement (Property 11)
    - **Property 11: lowRamProfile forces CPU backend for non-multimodal models**
    - **Validates: Requirements 6.5**

- [x] 6. Checkpoint — Ensure all Dart engine tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Platform availability guard and Huawei compatibility
  - [x] 7.1 Verify `shouldUseFlutterGemmaEngine` returns correct values for all platform combinations
    - Confirm `kIsWeb` check, `Platform.isAndroid`, `Platform.isIOS` logic
    - Huawei devices satisfy `Platform.isAndroid` — no special-casing needed
    - _Requirements: 10.2, 11.4_

  - [x] 7.2 Write property test for shouldUseFlutterGemmaEngine (Property 15)
    - **Property 15: shouldUseFlutterGemmaEngine returns true only on Android/iOS**
    - **Validates: Requirements 10.2, 11.4**
    - Test all platform combinations using platform override in tests

  - [x] 7.3 Verify `ensureLoaded` throws `LlmUnavailableException` on non-mobile platforms
    - Confirm the `!shouldUseFlutterGemmaEngine` guard at the top of `_ensureLoadedBody`
    - _Requirements: 10.1_

  - [x] 7.4 Write unit test for non-mobile platform guard
    - **Validates: Requirements 10.1**

  - [x] 7.5 Verify `GemmaHfModelDownloadService.isPluginModelInstalled` returns `false` on web
    - Confirm `kIsWeb` early return in `isPluginModelInstalled`
    - _Requirements: 10.3, 11.5_

  - [x] 7.6 Write unit test for isPluginModelInstalled returns false on web
    - **Validates: Requirements 10.3**

  - [x] 7.7 Verify Android `build.gradle.kts` inference dependencies are GMS-free
    - Confirm `litertlm-android` and `tasks-genai` have no `com.google.android.gms` transitive dependencies that would break Huawei builds
    - _Requirements: 11.3_

- [x] 8. Streaming lifecycle and cancellation
  - [x] 8.1 Verify Android streaming posts each chunk to main thread before `sink.success`
    - Confirm `mainHandler.post { sink.success(combined) }` in both `litertGenerateStream` and `mediaPipeGenerateStream`
    - _Requirements: 4.9_

  - [x] 8.2 Verify Android streaming calls `sink.endOfStream()` on success and `sink.error(...)` on failure
    - Confirm the `mainHandler.post { sink.endOfStream() }` and error paths in `generateStream`
    - _Requirements: 4.2, 4.3_

  - [x] 8.3 Verify iOS streaming calls `events(FlutterEndOfEventStream)` on success
    - Confirm the `events(FlutterEndOfEventStream)` call after the async stream loop in `NativeLlmStreamHandler.onListen`
    - _Requirements: 4.2_

  - [x] 8.4 Write unit test for stream end-of-stream signalling
    - **Property 6 (example): Streaming emits tokens then closes**
    - **Validates: Requirements 4.1, 4.2**

- [x] 9. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties; unit tests validate specific examples and edge cases
- The existing `NativeLlmBridge.kt` and `NativeLlmPlugin.swift` are already substantially correct — most tasks are verification + test coverage rather than new implementation
- Huawei compatibility requires no new code: `litertlm-android` and `tasks-genai` are GMS-free and `Platform.isAndroid` is true on Huawei devices
