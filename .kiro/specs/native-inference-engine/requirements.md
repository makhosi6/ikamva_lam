# Requirements Document

## Introduction

The learner app performs on-device LLM inference using a custom native engine implemented via Flutter MethodChannels and EventChannels. The engine bridges Dart to platform-native inference runtimes: **LiteRT-LM** (Google AI Edge, `.litertlm` format) on Android/Huawei and **MediaPipe GenAI** (`LlmInference`) on iOS and as a fallback on Android/Huawei. This replaces any dependency on the `flutter_gemma` pub package with a fully owned, in-tree native implementation.

The native engine must support:
- Loading a model from an absolute file path on disk (weights downloaded separately).
- One-shot (blocking) text generation with configurable sampling parameters.
- Streaming token-by-token generation via EventChannel.
- GPU/CPU backend selection with automatic CPU fallback on GPU failure.
- Multimodal flags (vision, audio) forwarded to the underlying runtime.
- Clean resource lifecycle: load, generate (one or many times), close.
- Consistent channel protocol between Dart and all native platforms (Android, iOS, Huawei).
- Huawei devices (HMS/EMUI) treated as Android with the same LiteRT-LM / MediaPipe stack, with GMS-absent fallback handling.

## Glossary

- **NativeLlmBridge**: The native-side singleton (Kotlin object on Android/Huawei, Swift enum on iOS) that owns the inference runtime handle and handles MethodChannel/EventChannel calls.
- **NativeLlmPlatform**: The Dart-side static class that wraps the MethodChannel and EventChannel, providing typed `loadModel`, `closeModel`, `generate`, and `generateStream` calls.
- **FlutterGemmaLlmEngine**: The Dart `LlmEngine` implementation that orchestrates model install, open, generate, and dispose using `NativeLlmPlatform`.
- **LlmEngine**: The abstract Dart interface (`ensureLoaded`, `generate`, `dispose`) that all on-device backends implement.
- **StreamingLlmCapability**: Optional Dart interface (`generateChunkStream`) for token-streaming engines.
- **LiteRT-LM**: Google AI Edge runtime for `.litertlm` model bundles on Android and Huawei (library: `com.google.ai.edge.litertlm:litertlm-android`).
- **MediaPipe GenAI**: Google MediaPipe `LlmInference` runtime for `.task`/`.bin`/`.tflite` model files on Android/Huawei and iOS (library: `com.google.mediapipe:tasks-genai` / CocoaPod `MediaPipeTasksGenAI`).
- **MethodChannel**: Flutter bidirectional RPC channel (`za.co.ikamvalam/native_llm`) used for `loadModel`, `closeModel`, and `generate`.
- **EventChannel**: Flutter one-way stream channel (`za.co.ikamvalam/native_llm_stream`) used for streaming token generation.
- **Sampling parameters**: `temperature`, `topK`, `topP`, `randomSeed`, `enableThinking` — forwarded from Dart to the native session.
- **Multimodal flags**: `supportImage`, `supportAudio`, `maxNumImages` — forwarded to the runtime to enable vision/audio modalities.
- **GPU backend**: Hardware-accelerated inference path (Metal on iOS, GPU delegate on Android/Huawei).
- **CPU backend**: Software inference path used as fallback when GPU is unavailable or fails.
- **`.litertlm`**: LiteRT-LM model bundle format used on Android and Huawei.
- **`.task` / `.bin` / `.tflite`**: MediaPipe model file formats used on Android/Huawei (fallback) and iOS.
- **Conversation / Session**: A single inference context created per `generate` or `generateStream` call and closed immediately after.
- **Huawei / HMS**: Huawei Mobile Services devices (EMUI/HarmonyOS) that run Android-compatible APKs but may lack Google Mobile Services (GMS). The same Kotlin `NativeLlmBridge` is used; GMS-dependent APIs (e.g., Google Play Services) are not used by the inference stack.

---

## Requirements

### Requirement 1: Channel Registration and Lifecycle

**User Story:** As a Flutter developer, I want the native inference channels to be registered at app startup, so that Dart can invoke inference methods without manual setup.

#### Acceptance Criteria

1. WHEN the Android `MainActivity` initialises its `FlutterEngine`, THE `NativeLlmBridge` SHALL register both the MethodChannel (`za.co.ikamvalam/native_llm`) and the EventChannel (`za.co.ikamvalam/native_llm_stream`) on the engine's binary messenger.
2. WHEN the iOS `AppDelegate` initialises the implicit Flutter engine, THE `NativeLlmBridge` SHALL register both channels on the plugin registrar's messenger.
3. THE `NativeLlmPlatform` Dart class SHALL expose `loadModel`, `closeModel`, `generate`, and `generateStream` as static methods backed by the registered channels.
4. WHEN an unrecognised method name is invoked on the MethodChannel, THE native bridge SHALL return `FlutterMethodNotImplemented` (Android/Huawei) or call `result(FlutterMethodNotImplemented)` (iOS).
5. WHEN the app runs on a Huawei device (HMS/EMUI), THE `NativeLlmBridge` SHALL register channels using the same Kotlin code path as standard Android, requiring no Huawei-specific registration logic.

### Requirement 2: Model Loading

**User Story:** As the inference engine, I want to load a model from an absolute file path, so that inference can begin without bundling weights in the app binary.

#### Acceptance Criteria

1. WHEN `loadModel` is called with a valid `modelPath`, `maxTokens`, `preferGpu`, `supportImage`, `supportAudio`, and `maxNumImages`, THE `NativeLlmBridge` SHALL open the model file and initialise the appropriate runtime (LiteRT-LM for `.litertlm` on Android; MediaPipe for all other formats and for iOS).
2. WHEN `loadModel` is called and a model is already loaded, THE `NativeLlmBridge` SHALL close the existing runtime before opening the new one.
3. WHEN the `modelPath` argument is missing or not a string, THE `NativeLlmBridge` SHALL return an error with code `bad_args`.
4. WHEN the file at `modelPath` does not exist on disk, THE `NativeLlmBridge` SHALL return an error with code `load_failed` and a message identifying the missing path.
5. WHEN `preferGpu` is `true`, THE `NativeLlmBridge` SHALL configure the runtime to use the GPU backend; WHEN `preferGpu` is `false`, THE `NativeLlmBridge` SHALL configure the CPU backend.
6. WHEN `maxNumImages` is greater than zero and `supportImage` is `true`, THE `NativeLlmBridge` SHALL configure the runtime's vision modality with the specified image count.
7. WHEN `supportAudio` is `true`, THE `NativeLlmBridge` SHALL enable the audio modality on the runtime.
8. WHEN `loadModel` succeeds, THE `NativeLlmBridge` SHALL return `null` (success) to the Dart caller.

### Requirement 3: One-Shot Generation

**User Story:** As the inference engine, I want to run a single blocking generation call, so that the app can get a complete response for prompt-based tasks.

#### Acceptance Criteria

1. WHEN `generate` is called with a `prompt`, `temperature`, `topK`, `topP`, `randomSeed`, `enableThinking`, and `maxNewTokens`, THE `NativeLlmBridge` SHALL create a new session, run inference to completion, close the session, and return the full response string.
2. WHEN `generate` is called and no model is loaded, THE `NativeLlmBridge` SHALL return an error with code `generate_failed` and a message indicating the model is not loaded.
3. WHEN the model is a `.litertlm` file on Android, THE `NativeLlmBridge` SHALL use the LiteRT-LM `Conversation` API for generation.
4. WHEN the model is a non-`.litertlm` file on Android or any file on iOS, THE `NativeLlmBridge` SHALL use the MediaPipe `LlmInferenceSession` API for generation.
5. WHEN `enableThinking` is `true` and the runtime is LiteRT-LM, THE `NativeLlmBridge` SHALL pass `enable_thinking` in the generation extras and prepend any `thought` channel content to the response using the `<|channel>thought\n…<channel|>` format.
6. WHEN `enableThinking` is `true` and the runtime is MediaPipe, THE `NativeLlmBridge` SHALL log a warning that `enableThinking` is ignored for MediaPipe and proceed with generation.
7. WHEN generation fails due to a runtime error, THE `NativeLlmBridge` SHALL return an error with code `generate_failed` and the error message.
8. WHEN `generate` is called on Android, THE `NativeLlmBridge` SHALL execute inference on a background thread and post the result to the main thread before calling `result.success`.

### Requirement 4: Streaming Generation

**User Story:** As the inference engine, I want to stream token chunks to Dart as they are produced, so that the UI can display partial responses progressively.

#### Acceptance Criteria

1. WHEN the EventChannel `onListen` is called with generation arguments, THE `NativeLlmBridge` SHALL begin streaming token chunks to the `EventSink` as they are produced by the runtime.
2. WHEN streaming completes successfully, THE `NativeLlmBridge` SHALL signal end-of-stream to the `EventSink` (Android: `sink.endOfStream()`; iOS: `events(FlutterEndOfEventStream)`).
3. WHEN streaming fails with a runtime error, THE `NativeLlmBridge` SHALL send an error event to the `EventSink` with code `stream_failed`.
4. WHEN the EventChannel `onCancel` is called, THE `NativeLlmBridge` SHALL cancel any in-flight streaming task and release associated resources.
5. WHEN the model is a `.litertlm` file on Android, THE `NativeLlmBridge` SHALL use the LiteRT-LM `MessageCallback` API for streaming.
6. WHEN the model is a non-`.litertlm` file on Android, THE `NativeLlmBridge` SHALL use the MediaPipe `generateResponseAsync` callback API for streaming.
7. WHEN streaming on iOS, THE `NativeLlmBridge` SHALL use MediaPipe's `generateResponseAsync()` async sequence and forward each chunk to the event sink on the main actor.
8. WHEN a streaming chunk contains LiteRT-LM `thought` channel content, THE `NativeLlmBridge` SHALL prepend it to the chunk using the `<|channel>thought\n…<channel|>` format before sending to the sink.
9. WHEN streaming on Android, THE `NativeLlmBridge` SHALL post each chunk to the main thread via `Handler(Looper.getMainLooper())` before calling `sink.success`.

### Requirement 5: Model Close and Resource Cleanup

**User Story:** As the inference engine, I want to release native resources when the model is no longer needed, so that memory is freed and the device is not burdened.

#### Acceptance Criteria

1. WHEN `closeModel` is called, THE `NativeLlmBridge` SHALL close and release the active LiteRT-LM engine (if any) and the active MediaPipe `LlmInference` instance (if any).
2. WHEN `closeModel` is called and no model is loaded, THE `NativeLlmBridge` SHALL return success without error.
3. WHEN `closeModel` is called on Android, THE `NativeLlmBridge` SHALL execute the close operation on the background executor thread and post success to the main thread.
4. WHEN `FlutterGemmaLlmEngine.dispose` is called in Dart, THE engine SHALL invoke `NativeLlmPlatform.closeModel` asynchronously and suppress any errors from the close call.
5. WHEN a `Conversation` or `LlmInferenceSession` is created for a single generation call, THE `NativeLlmBridge` SHALL close it in a `finally` block regardless of success or failure.

### Requirement 6: GPU/CPU Backend Selection and Fallback

**User Story:** As the inference engine, I want to prefer GPU inference but fall back to CPU when GPU fails, so that the app works on a wide range of devices.

#### Acceptance Criteria

1. WHEN `FlutterGemmaLlmEngine.ensureLoaded` is called and `preferGpu` is `true`, THE engine SHALL first attempt to open the model with `preferGpu: true`.
2. WHEN the GPU open attempt fails and the model is not multimodal, THE `FlutterGemmaLlmEngine` SHALL retry the open with `preferGpu: false`.
3. WHEN the GPU open attempt fails and the model is multimodal (vision or audio), THE `FlutterGemmaLlmEngine` SHALL NOT fall back to CPU and SHALL propagate the error.
4. WHEN `IKAMVA_FORCE_CPU_BACKEND` is set to a non-zero or `true` value at compile time, THE `FlutterGemmaLlmEngine` SHALL always pass `preferGpu: false` regardless of the settings profile.
5. WHEN `SettingsStore.lowRamProfile` is `true` and the model is not multimodal, THE `FlutterGemmaLlmEngine` SHALL pass `preferGpu: false`.
6. WHEN a GPU resource exhaustion error is detected (queue buffer timeout, memory pressure, GPU stall), THE `FlutterGemmaLlmEngine` SHALL delay 400 ms and retry; IF the model is non-multimodal, THE engine SHALL retry with CPU backend.

### Requirement 7: Dart-Side Engine Interface

**User Story:** As a Dart developer, I want a clean `LlmEngine` interface backed by the native channels, so that the rest of the app is decoupled from platform-specific inference details.

#### Acceptance Criteria

1. THE `FlutterGemmaLlmEngine` SHALL implement the `LlmEngine` interface (`ensureLoaded`, `generate`, `dispose`).
2. THE `FlutterGemmaLlmEngine` SHALL implement the `StreamingLlmCapability` interface (`generateChunkStream`).
3. WHEN `generate` is called before `ensureLoaded` completes, THE `FlutterGemmaLlmEngine` SHALL call `ensureLoaded` automatically before invoking the native channel.
4. WHEN `ensureLoaded` is called concurrently from multiple callers, THE `FlutterGemmaLlmEngine` SHALL deduplicate the load into a single in-flight `Future` so the native model is opened exactly once.
5. WHEN `generate` or `generateChunkStream` is called after `dispose`, THE `FlutterGemmaLlmEngine` SHALL throw a `StateError`.
6. WHEN a native `generate` call fails, THE `FlutterGemmaLlmEngine` SHALL wrap the error in `LlmResourceException`.
7. WHEN `generateChunkStream` is called, THE `FlutterGemmaLlmEngine` SHALL return a `Stream<String>` that emits token chunks and closes on completion or error.
8. WHEN stop sequences are provided in `LlmGenerateRequest`, THE `FlutterGemmaLlmEngine` SHALL truncate the response at the first occurrence of any stop sequence after receiving the native result.

### Requirement 8: Channel Protocol Consistency

**User Story:** As a developer maintaining both platforms, I want the MethodChannel and EventChannel argument schemas to be identical on Android and iOS, so that the Dart layer does not need platform-specific branching.

#### Acceptance Criteria

1. THE `loadModel` method SHALL accept a `Map<String, Object?>` with keys: `modelPath` (String), `maxTokens` (int), `preferGpu` (bool), `supportImage` (bool), `supportAudio` (bool), `maxNumImages` (int).
2. THE `generate` method SHALL accept a `Map<String, Object?>` with keys: `prompt` (String), `temperature` (double), `topK` (int), `topP` (double), `randomSeed` (int), `enableThinking` (bool), `maxNewTokens` (int).
3. THE `generateStream` EventChannel SHALL accept the same argument map as `generate` and emit String tokens or Map events with a `token` key.
4. WHEN the EventChannel emits an error event, THE event SHALL be a Map with an `error` key containing the error message string.
5. THE channel names SHALL be `za.co.ikamvalam/native_llm` (MethodChannel) and `za.co.ikamvalam/native_llm_stream` (EventChannel) on both platforms.

### Requirement 9: Error Classification and Recovery

**User Story:** As the inference engine, I want to classify native errors into actionable categories, so that the app can present meaningful messages and attempt appropriate recovery.

#### Acceptance Criteria

1. WHEN a native error message contains `modifygraphwithdelegate`, `gpu_delegate`, `llm_litert_metal`, `litert_metal_executor`, `tflitegpudelegate`, or (`metal` AND `delegate`), THE `FlutterGemmaLlmEngine` SHALL classify it as a GPU Metal delegate failure.
2. WHEN a native error message contains `queue_buffer_timeout`, `gpu completion`, `queue buffer`, `lost connection`, `opengl`, `opencl`, `gpu stall`, `memory pressure`, or (`timeout` AND (`gpu` OR `render`)), THE `FlutterGemmaLlmEngine` SHALL classify it as GPU resource exhaustion.
3. WHEN a native error message contains `zip archive` or `unable to open zip` (and is NOT a GPU Metal delegate failure), THE `FlutterGemmaLlmEngine` SHALL classify it as an invalid task archive.
4. WHEN an invalid task archive error occurs after reinstall, THE `FlutterGemmaLlmEngine` SHALL throw `LlmUnavailableException` with a user-facing hint specific to the active variant.
5. WHEN a storage-full error occurs during download (message contains `space`, `storage`, or `enospc`), THE `FlutterGemmaLlmEngine` SHALL throw `LlmResourceException`.

### Requirement 10: Platform Availability Guard

**User Story:** As the inference engine, I want to guard native inference to mobile platforms only, so that the app does not crash on web or desktop.

#### Acceptance Criteria

1. WHEN `FlutterGemmaLlmEngine.ensureLoaded` is called on a non-Android, non-iOS platform, THE engine SHALL throw `LlmUnavailableException` with the message `On-device Gemma runs on Android and iOS only.`
2. THE `shouldUseFlutterGemmaEngine` getter SHALL return `true` only when `Platform.isAndroid` or `Platform.isIOS` is `true` and `kIsWeb` is `false`.
3. WHEN `GemmaHfModelDownloadService.isPluginModelInstalled` is called on a web platform, THE service SHALL return `false` without accessing the file system.

### Requirement 11: Huawei Device Compatibility

**User Story:** As a learner using a Huawei device, I want the on-device inference engine to work on my phone, so that I can use the app even without Google Mobile Services.

#### Acceptance Criteria

1. WHEN the app runs on a Huawei device with EMUI or HarmonyOS (Android-compatible APK), THE `NativeLlmBridge` SHALL load and run inference using the same LiteRT-LM / MediaPipe stack as standard Android, with no GMS dependency in the inference path.
2. WHEN the Huawei device GPU driver does not support the GPU delegate, THE `NativeLlmBridge` SHALL surface a `load_failed` error so that `FlutterGemmaLlmEngine` can fall back to the CPU backend per Requirement 6.
3. WHEN building for Huawei distribution (e.g., AppGallery), THE Android `build.gradle.kts` SHALL NOT require Google Play Services APIs in the inference dependencies (`litertlm-android` and `tasks-genai` are GMS-free).
4. WHEN `shouldUseFlutterGemmaEngine` is evaluated on a Huawei Android device, THE getter SHALL return `true` because `Platform.isAndroid` is `true`.
5. WHEN the model file path is resolved on a Huawei device, THE `GemmaHfModelDownloadService` SHALL use `getApplicationDocumentsDirectory()` which resolves correctly on EMUI/HarmonyOS without special-casing.
