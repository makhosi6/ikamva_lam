# Native on-device LLM: prompts and outputs

Architecture for **MethodChannel / EventChannel** inference after the `.litertlm` file is downloaded to app documents.

```mermaid
flowchart LR
  subgraph Flutter_Dart["Flutter (Dart)"]
    UI["UI / BLoC / LlmService"]
    Engine["FlutterGemmaLlmEngine"]
    Plat["NativeLlmPlatform\nMethodChannel + EventChannel"]
    UI --> Engine
    Engine --> Plat
  end

  subgraph Android_Native["Android (Kotlin)"]
    BridgeA["NativeLlmBridge"]
    LiteRT["LiteRT-LM Engine\n(.litertlm)"]
    MP["MediaPipe LlmInference\n(.task / .bin / .tflite)"]
    Plat -->|invoke| BridgeA
    BridgeA --> LiteRT
    BridgeA --> MP
  end

  subgraph iOS_Native["iOS (Swift)"]
    BridgeI["NativeLlmBridge"]
    MPIOS["MediaPipe LlmInference\n(path on disk)"]
    Plat -->|invoke| BridgeI
    BridgeI --> MPIOS
  end

  subgraph Artifacts["On disk"]
    HF["Hugging Face download\n→ Documents/*.litertlm"]
  end

  HF --> BridgeA
  HF --> BridgeI

  subgraph IO["Data flow"]
    P["Prompt text\n(+ sampling args)"]
    O["Completion text\nor token stream"]
  end

  Engine --> P
  O --> Engine
```

## Inputs (prompt path)

- **`loadModel`:** absolute `modelPath`, `maxTokens`, `preferGpu`, multimodal flags (`supportImage`, `supportAudio`, `maxNumImages`).
- **`generate` / stream:** `prompt` (user text), `temperature`, `topK`, `topP`, `randomSeed`, `enableThinking`, optional `maxNewTokens`.

## Outputs

- **`generate`:** single completion string (then Dart applies stop sequences and JSON helpers).
- **`generateStream`:** sequence of token/chunk strings via EventChannel until end of stream.
