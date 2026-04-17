# Native runtime — llama.cpp + Gemma (Phase 6)

This tree holds **build scripts and documentation** for on-device inference. **GGUF weights stay out of git** (see root `.gitignore`).

## Integration strategy (TASKS §6.1) — **chosen: subprocess CLI first**

| Approach | Pros | Cons |
|----------|------|------|
| **`dart:ffi` + bundled `libllama`** | Lowest latency; reuse context in-process (§6.8) | Per-ABI builds (Android arm64, iOS, desktop); harder CI; bigger app. |
| **Subprocess → `llama-cli`** (current) | One binary per dev machine; easy to swap llama.cpp rev; **CI stays green** without native libs. | Process spawn overhead; JSON mode needs stdout parsing. |
| **Platform channel (Kotlin/Swift)** | Good for Play/App Store packaging | Two native codepaths + JNI/FFI still required. |

**Decision:** ship the **Flutter `Process` + `llama-cli`** path for hackathon velocity, document **FFI** as the upgrade when latency and context reuse matter. The Dart API (`LlmEngine` / `LlmService`) is written so the backing implementation can be swapped.

## Pinned upstream (TASKS §6.2)

- Commit: **`native/LLAMA_CPP_REF`** (full SHA, shallow-fetched in the build script).
- Build (macOS / Linux dev):

```bash
chmod +x native/scripts/build_llama_cli.sh
./native/scripts/build_llama_cli.sh
```

Output: **`native/build/bin/llama-cli`** (or `main` renamed — the script copies to `llama-cli`).

## Standalone smoke harness (TASKS §6.10)

Test **`llama-cli` + GGUF without Flutter** (same flags as `ProcessLlmEngine` / `runLlamaCliSync`):

```bash
chmod +x native/scripts/llama_cli_smoke.sh
export IKAMVA_GGUF=/absolute/path/to/your/model.gguf
# optional if binary is not at repo native/build/bin/llama-cli:
# export IKAMVA_LLAMA_CLI=/path/to/llama-cli
./native/scripts/llama_cli_smoke.sh
# stricter: require first balanced {...} to parse as JSON:
./native/scripts/llama_cli_smoke.sh --expect-json
```

Optional env: **`IKAMVA_MAX_NEW`** (default `120`), **`IKAMVA_CTX`** (default `768`), **`IKAMVA_PROMPT`** (override default JSON-only smoke string).

Exit codes: **`2`** missing binary/GGUF, **`3`** JSON check failed (`--expect-json`), otherwise **`llama-cli`’s exit code**.

## Gemma 4 GGUF (TASKS §6.3)

- **Quant:** `Q4_K_M` for demo machines; **`Q2_K` / E2B-class** for low-RAM profiles (toggle in app Settings).
- **Storage:** place the file anywhere on disk (e.g. `~/models/gemma-4-*.gguf`) — **not** committed.
- **Wire-up:** set **`IKAMVA_GGUF`** to the absolute path, and either rely on `native/build/bin/llama-cli` or set **`IKAMVA_LLAMA_CLI`** to the CLI binary.
- **Checksum:** after download, record SHA-256 in your team vault; update this README with the exact filename you ship to judges.

Official weights and naming change with releases — follow [Google AI Gemma](https://ai.google.dev/gemma) / Kaggle / Hugging Face listings for the **Gemma 3n** / **Gemma 4** GGUF you choose.

## CLI invocation (reference)

The Dart `ProcessLlmEngine` uses a conservative argument set; adjust if your `llama-cli` revision differs:

```text
llama-cli -m <model.gguf> -p "<prompt>" -n <max_new> -c <ctx> --no-display-prompt
```

JSON-only prompts should still be post-processed (see `LlmOutputFilters` in Dart) to stop at the first complete `{ ... }`.

## Flutter wiring

- **`IKAMVA_LLAMA_CLI`**: absolute path to CLI (optional if `native/build/bin/llama-cli` exists relative to cwd).
- **`IKAMVA_GGUF`**: absolute path to `.gguf`.
- **`IKAMVA_USE_STUB_LLM=1`**: force stub engine (tests / CI).

When the CLI or model path is missing, the app uses **`StubLlmEngine`** so `flutter test` and CI never require native binaries.
