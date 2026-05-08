# On-device Gemma: Hugging Face download

The learner app **does not** ship Gemma **`.litertlm`** weights in the APK/IPA.
Learners pick **E2B** or **E4B** and download from **Hugging Face** (`fromNetwork`),
same pattern as the `flutter_gemma` example app’s model download service.

## Install path

1. **`FlutterGemma.installModel`…`fromNetwork(url)`** (with optional HF token)
   downloads into plugin storage.
2. **`getActiveModel`** opens the registered model for inference.

Implementation: [`lib/llm/flutter_gemma_llm_engine.dart`](../lib/llm/flutter_gemma_llm_engine.dart),
[`lib/llm/gemma_hf_model_download_service.dart`](../lib/llm/gemma_hf_model_download_service.dart).

## Cold start routing

After onboarding, **`SplashScreen`** and **`WelcomeScreen`** navigate to **`/home`**
only. There is **no** separate prepare route.

If weights are missing or corrupt, **`ensureReady()`** on the home hub (or
**Settings → Warm up model**) surfaces errors — use **Set-up Gemma 4** to
download again.

## Home hub

The home hub calls **`LlmService.instance.ensureReady()`** on mobile before
loading topics, with optional verbose lifecycle via **`LlmService.configure`**.

## Configuration

[`lib/llm/model_prepare_config.dart`](../lib/llm/model_prepare_config.dart) —
optional **`IKAMVA_MODEL_*`** compile-time defines affect **free-space** hints
and context limits.

Prepare prefs store **`network:<url>`** as the install fingerprint
([`model_prepare_prefs.dart`](../lib/llm/model_prepare_prefs.dart)).

## Purge / recovery

[`purgeGemmaPluginInstallCandidates`](../lib/llm/flutter_gemma_llm_engine.dart)
unregisters plugin model ids derived from HF URLs plus legacy ids from older
builds.

## Related

- URLs: [`lib/llm/gemma_model_config.dart`](../lib/llm/gemma_model_config.dart)
