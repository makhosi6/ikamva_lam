# Changelog

## Unreleased

### Changed

- **On-device catalog:** Learners choose **Gemma 3n** (E2B / E4B) or **Gemma 4** (E2B / E4B) `.litertlm` from Hugging Face. Default recommendation: **Gemma 3n E2B**. Gemma 3n needs **`IKAMVA_HF_TOKEN`**; Gemma 4 litert-community artifacts are public.
- **Model delivery:** Weights download into app documents (not bundled in the APK). See `learner_app/docs/model_delivery.md`. Prepare prefs store a **`network:<url>`** fingerprint per variant.
- **Setup gate:** `/gemma-setup` lists all four variants; Settings → **Choose on-device model**.
- **GPU mid-range crashes:** Prefer Low RAM / `IKAMVA_FORCE_CPU_BACKEND=1` when OpenCL init stalls (see `gpu_timeout_fix.md`).
- **LLM stack:** Native LiteRT-LM (Android) / MediaPipe (iOS) MethodChannels. Stub engine for CI / desktop tests.

### Developer / CI

- **VS Code:** `--dart-define-from-file=.env` — set **`IKAMVA_HF_TOKEN`** for Gemma 3n.
- **GitHub Actions:** ensure repo-root `.env` exists for dart-define-from-file.

### Documentation

- Updated **`README.md`**, **`spec.md`**, **`writeup.md`**, **`TASKS.md`**, **`docs/plan-gemma4-model-selection.md`**, and **`learner_app/docs/model_delivery.md`** for the Gemma 3n + Gemma 4 catalog.

## Older

See git history for prior bundled-asset / flutter_gemma plugin migration notes.
