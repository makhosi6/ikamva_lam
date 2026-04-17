# Native runtime (llama.cpp + Gemma)

This folder is reserved for **llama.cpp** integration with the Flutter learner app.

## Planned stack

1. Build **llama.cpp** as a shared library for each target (Android `arm64-v8a`, iOS, macOS).
2. Expose a small C API (load model, run completion with max tokens and stop sequences).
3. Bridge from Dart via **`dart:ffi`** or platform channels (document the choice in the root README when decided).
4. Ship **Gemma 4** weights as **GGUF** `Q4_K_M`; keep files **out of git** (see root `.gitignore`).

## References

- Project constraints: [spec.md](../spec.md) §3.2–3.3, §7.
- Build task checklist: [TASKS.md](../TASKS.md) Phase 6.

No build scripts are committed yet; add `CMakeLists.txt` or platform projects here when Phase 6 starts.
