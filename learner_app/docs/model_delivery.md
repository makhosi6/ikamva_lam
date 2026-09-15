# On-device Gemma: Hugging Face download

The learner app **does not** ship Gemma weights in the APK/IPA.
Learners pick a **Gemma 3n** or **Gemma 4** `.litertlm` variant and download
from **Hugging Face** into app documents, then open via native LiteRT-LM
(Android) / MediaPipe GenAI (iOS).

## Catalog

| Variant | Artifact | Auth | Notes |
|---------|----------|------|-------|
| **Gemma 3n E2B** (default) | `google/gemma-3n-E2B-it-litert-lm` | HF token | Recommended; multimodal-capable |
| **Gemma 3n E4B** | `google/gemma-3n-E4B-it-litert-lm` | HF token | Larger; needs more RAM |
| **Gemma 4 E2B** | `litert-community/gemma-4-E2B-it-litert-lm` | Public | LiteRT prize track; prefer Low RAM / CPU on mid-range GPUs |
| **Gemma 4 E4B** | `litert-community/gemma-4-E4B-it-litert-lm` | Public | Stronger devices |

URLs and filenames: [`lib/llm/gemma_model_config.dart`](../lib/llm/gemma_model_config.dart).
Variant enum: [`lib/llm/on_device_gemma_variant.dart`](../lib/llm/on_device_gemma_variant.dart).

## Install path

1. **Setup screen** (`/gemma-setup`) downloads the chosen file with
   [`GemmaHfModelDownloadService`](../lib/llm/gemma_hf_model_download_service.dart)
   + [`DetailedSmartDownloader`](../lib/llm/detailed_smart_downloader.dart).
2. **`FlutterGemmaLlmEngine.ensureLoaded`** opens the on-disk path via
   `NativeLlmPlatform.loadModel` (cache-first when fingerprint matches).

## Auth (Gemma 3n)

Put a Hugging Face token with access to the gated Gemma 3n repos in
**repo-root `.env`** as `IKAMVA_HF_TOKEN=…`, or pass
`--dart-define=IKAMVA_HF_TOKEN=…`. Android also bakes the env-file token into
`BuildConfig` for release.

## Cold start routing

After onboarding, **Splash** / redirects send mobile users to **`/gemma-setup`**
until setup is marked complete, then **`/home`**.

If weights are missing or corrupt, **`ensureReady()`** on the home hub (or
**Settings → Warm up model**) surfaces errors — reopen **Choose on-device model**
to download again.

## Home hub

The home hub calls **`LlmService.instance.ensureReady()`** on mobile before
loading topics, with optional verbose lifecycle via **`LlmService.configure`**.

## Configuration

[`lib/llm/model_prepare_config.dart`](../lib/llm/model_prepare_config.dart) —
optional **`IKAMVA_MODEL_*`** compile-time defines affect **free-space** hints
and context limits. **`IKAMVA_FORCE_CPU_BACKEND=1`** avoids GPU stalls on some
MediaTek / mid-range devices (see [`gpu_timeout_fix.md`](gpu_timeout_fix.md)).

Prepare prefs store **`network:<url>`** as the install fingerprint
([`model_prepare_prefs.dart`](../lib/llm/model_prepare_prefs.dart)).

## Purge / recovery

[`purgeGemmaPluginInstallCandidates`](../lib/llm/flutter_gemma_llm_engine.dart)
deletes known filenames for **all** catalog variants plus legacy ids.

## Related

- GPU crashes / CPU fallback: [`gpu_timeout_fix.md`](gpu_timeout_fix.md)
- Root README “Models” section
