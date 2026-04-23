# On-device Gemma: bundled weights only

The learner app **never** fetches Gemma weights over HTTP. Weights come **only**
from **`assets/models/gemma-4-E2B-it.litertlm`** declared in **`pubspec.yaml`**.

## Install path

1. **`FlutterGemma.installModel`…`fromAsset(assetPath)`** copies from the Flutter
   asset bundle into plugin storage (large one-time copy on first use).
2. **`getActiveModel`** opens the registered model for inference.

Implementation: [`lib/llm/flutter_gemma_llm_engine.dart`](../lib/llm/flutter_gemma_llm_engine.dart),
[`lib/llm/model_asset_manifest.dart`](../lib/llm/model_asset_manifest.dart).

## Cold start routing

After onboarding, **`SplashScreen`** and **`WelcomeScreen`** navigate to **`/home`**
only. There is **no** separate prepare route.

If the weight file is **not** listed in **`AssetManifest.json`**, first
**`ensureReady()`** on the home hub (or **Settings → Warm up model**) fails with
a clear error — fix **`pubspec.yaml`** and rebuild.

## Home hub

[`lib/screens/home_hub_screen.dart`](../lib/screens/home_hub_screen.dart) calls
**`LlmService.instance.ensureReady()`** on mobile before loading topics, with
optional verbose lifecycle lines via **`LlmService.configure`**.

## Configuration

[`lib/llm/model_prepare_config.dart`](../lib/llm/model_prepare_config.dart) —
optional **`IKAMVA_MODEL_*`** compile-time defines affect **free-space** hints
in tests and docs only (no dedicated prepare UI).

Prepare prefs store **`bundle:…`** as the install fingerprint
([`model_prepare_prefs.dart`](../lib/llm/model_prepare_prefs.dart)).

## Purge / recovery

[`purgeGemmaPluginInstallCandidates`](../lib/llm/flutter_gemma_llm_engine.dart)
unregisters plugin model ids derived from the bundled filename plus legacy ids
from older builds.

## Related

- Operator checklist: [`assets/models/OBTAINING_MODELS.txt`](../assets/models/OBTAINING_MODELS.txt)
