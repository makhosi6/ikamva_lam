import Flutter
import Foundation
import MediaPipeTasksGenAI

/// Registers MethodChannel + EventChannel for **MediaPipe** `LlmInference` on iOS.
enum NativeLlmBridge {
  private static var inference: LlmInference?

  static func register(registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    FlutterMethodChannel(
      name: "za.co.ikamvalam/native_llm",
      binaryMessenger: messenger,
    ).setMethodCallHandler { call, result in
      handleMethod(call: call, result: result)
    }
    FlutterEventChannel(
      name: "za.co.ikamvalam/native_llm_stream",
      binaryMessenger: messenger,
    ).setStreamHandler(NativeLlmStreamHandler())
  }

  private static func handleMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadModel":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      guard let path = args["modelPath"] as? String, !path.isEmpty else {
        result(
          FlutterError(
            code: "bad_args",
            message: "missing or invalid modelPath",
            details: nil,
          ),
        )
        return
      }
      do {
        try loadModel(args: args)
        result(nil)
      } catch {
        result(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
      }
    case "closeModel":
      closeAll()
      result(nil)
    case "generate":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let text = try generateSync(args: args)
          DispatchQueue.main.async { result(text) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "generate_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func closeAll() {
    inference = nil
  }

  private static func loadModel(args: [String: Any]) throws {
    closeAll()
    guard let path = args["modelPath"] as? String, !path.isEmpty else {
      throw NSError(
        domain: "NativeLlm",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "missing modelPath"],
      )
    }
    guard FileManager.default.fileExists(atPath: path) else {
      throw NSError(domain: "NativeLlm", code: 2, userInfo: [NSLocalizedDescriptionKey: "model not found: \(path)"])
    }
    let maxTokens = (args["maxTokens"] as? NSNumber)?.intValue ?? 1024
    let preferGpu = (args["preferGpu"] as? Bool) ?? true
    let maxNumImages = (args["maxNumImages"] as? NSNumber)?.intValue ?? 0
    let supportImage = (args["supportImage"] as? Bool) ?? false
    let supportAudio = (args["supportAudio"] as? Bool) ?? false

    let options = LlmInference.Options(modelPath: path)
    options.maxTokens = maxTokens
    options.waitForWeightUploads = true
    // Req 2.6 + design Property 1: vision only when both flags are set.
    if supportImage && maxNumImages > 0 {
      options.maxImages = maxNumImages
    }
    options.preferredBackend = preferGpu ? .gpu : .cpu
    if supportAudio {
      options.enableAudioModality = true
    }

    inference = try LlmInference(options: options)
  }

  private static func generateSync(args: [String: Any]) throws -> String {
    guard let llm = inference else {
      throw NSError(domain: "NativeLlm", code: 3, userInfo: [NSLocalizedDescriptionKey: "model not loaded"])
    }
    let prompt = args["prompt"] as? String ?? ""
    let temperature = (args["temperature"] as? NSNumber)?.floatValue ?? 1.0
    let topK = (args["topK"] as? NSNumber)?.intValue ?? 64
    let topP = (args["topP"] as? NSNumber)?.doubleValue ?? 0.95
    let randomSeed = (args["randomSeed"] as? NSNumber)?.intValue ?? 0
    let enableVision = (args["supportImage"] as? Bool) ?? false
    let enableAudio = (args["supportAudio"] as? Bool) ?? false

    let sessionOptions = LlmInference.Session.Options()
    sessionOptions.temperature = temperature
    sessionOptions.randomSeed = randomSeed
    sessionOptions.topk = topK
    sessionOptions.topp = Float(topP)
    sessionOptions.enableVisionModality = enableVision
    sessionOptions.enableAudioModality = enableAudio

    let session = try LlmInference.Session(llmInference: llm, options: sessionOptions)
    try session.addQueryChunk(inputText: prompt)
    return try session.generateResponse()
  }

  /// Must run in a Swift `Task` — uses `for try await` on MediaPipe’s async stream.
  fileprivate static func generateStreamAsync(
    args: [String: Any],
    events: FlutterEventSink?,
  ) async throws {
    guard let llm = inference else {
      throw NSError(domain: "NativeLlm", code: 3, userInfo: [NSLocalizedDescriptionKey: "model not loaded"])
    }
    let prompt = args["prompt"] as? String ?? ""
    let temperature = (args["temperature"] as? NSNumber)?.floatValue ?? 1.0
    let topK = (args["topK"] as? NSNumber)?.intValue ?? 64
    let topP = (args["topP"] as? NSNumber)?.doubleValue ?? 0.95
    let randomSeed = (args["randomSeed"] as? NSNumber)?.intValue ?? 0
    let enableVision = (args["supportImage"] as? Bool) ?? false
    let enableAudio = (args["supportAudio"] as? Bool) ?? false

    let sessionOptions = LlmInference.Session.Options()
    sessionOptions.temperature = temperature
    sessionOptions.randomSeed = randomSeed
    sessionOptions.topk = topK
    sessionOptions.topp = Float(topP)
    sessionOptions.enableVisionModality = enableVision
    sessionOptions.enableAudioModality = enableAudio

    let session = try LlmInference.Session(llmInference: llm, options: sessionOptions)
    try session.addQueryChunk(inputText: prompt)

    let stream = try session.generateResponseAsync()
    for try await chunk in stream {
      try Task.checkCancellation()
      await MainActor.run {
        events?(chunk)
      }
    }
  }
}

private final class NativeLlmStreamHandler: NSObject, FlutterStreamHandler {
  private var streamingTask: Task<Void, Never>?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    streamingTask?.cancel()
    guard let args = arguments as? [String: Any] else {
      return FlutterError(code: "bad_args", message: nil, details: nil)
    }
    streamingTask = Task(priority: .userInitiated) {
      do {
        try await NativeLlmBridge.generateStreamAsync(args: args, events: events)
        guard !Task.isCancelled else { return }
        await MainActor.run { events(FlutterEndOfEventStream) }
      } catch is CancellationError {
        // Listener cancelled — no terminal event required.
      } catch {
        await MainActor.run {
          events(
            FlutterError(code: "stream_failed", message: error.localizedDescription, details: nil)
          )
        }
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    streamingTask?.cancel()
    streamingTask = nil
    return nil
  }
}
