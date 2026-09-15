# Plan: On-device Gemma model selection (Gemma 3n + Gemma 4)

Updated for the finished learner app: model choice **before** the home hub’s
warm-up phase, catalog includes **Gemma 3n** and **Gemma 4**.

## Goals

1. Pre-hub setup at `/gemma-setup` — choose → download → confirm → `/home`.
2. Support **Gemma 3n E2B/E4B** (gated HF, multimodal-capable) and **Gemma 4 E2B/E4B**
   (public litert-community).
3. Default recommendation: **Gemma 3n E2B** (stable on mid-range devices; HF token required).
4. Hub only calls `ensureReady()` for the already-chosen install.

## Catalog

| Variant | Source | Auth |
|---------|--------|------|
| Gemma 3n E2B | `google/gemma-3n-E2B-it-litert-lm` | Required |
| Gemma 3n E4B | `google/gemma-3n-E4B-it-litert-lm` | Required |
| Gemma 4 E2B | `litert-community/gemma-4-E2B-it-litert-lm` | Public |
| Gemma 4 E4B | `litert-community/gemma-4-E4B-it-litert-lm` | Public |

Implemented in `OnDeviceGemmaVariant`, `GemmaModelConfig`, setup UI, and
`FlutterGemmaLlmEngine`.

## Out of scope

- Embedding / RAG catalog rows from the flutter_gemma example.
- Enabling vision/audio in the learner path (flags stay `false` until the app
  passes image/audio into `generate`).
