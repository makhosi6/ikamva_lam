# Changelog

## Unreleased

### Changed

- **Bundled Gemma:** **`gemma-4-E2B-it.litertlm`** ships under **`learner_app/assets/models/`**, is listed in **`pubspec.yaml`**, and installs with **`FlutterGemma.installModel(…).fromAsset`**. Weights are **not** fetched over the network. Prepare prefs store a **`bundle:<asset path>`** fingerprint. **`FlutterGemmaLlmEngine.ensureLoaded`** throws **`LlmUnavailableException`** on non-Android/iOS hosts so desktop **`flutter test`** stays predictable.

- **Wrong URL guard (validation / tests):** URLs containing **`-web.task`** are treated as **Web-only** per `flutter_gemma`; production mobile uses **`.litertlm`** — see `OBTAINING_MODELS.txt`.

- **LLM stack:** Replaced the `llama-cli` / GGUF subprocess path with **`flutter_gemma`** on Android and iOS. **`ProcessLlmEngine`** and the **`native/`** tree are removed.

- **Model delivery:** **Asset-only** — no **`IKAMVA_MODEL_DOWNLOAD_URL`**, **`IKAMVA_HF_TOKEN`**, or **`ModelLocalCache`**. See `learner_app/docs/model_delivery.md` and **`OBTAINING_MODELS.txt`**.

- **Persistence & recovery:** **`getActiveModel`** is preferred on load. **`FlutterGemmaLlmEngine.ensureLoaded`** tries open → purge + re-install **from the bundled asset** on failure. **`LlmService.ensureReady`** timeout remains **600s** for large copies.

- **Cold start / prepare:** After onboarding, **`SplashScreen`** / **`WelcomeScreen`** go to **`/home`** only. **`HomeHubScreen`** runs **`LlmService.instance.ensureReady()`** (bundled **`fromAsset`**) before topics, with verbose lifecycle when configured. **`probeFlutterGemmaActiveModelReady`** and **`purgeGemmaPluginInstallCandidates`** still support recovery from corrupt installs. Layout: no **`Spacer`** inside scrollable **`ConstrainedContent`**; **`ConstrainedContent(scrollable: false)`** on **Developer** stats where a **`ListView`** is the primary scroller.

- **Prepare-state robustness:** model prepare persistence stores **done flag + install fingerprint + prepared timestamp**. When the **`bundle:…`** fingerprint changes, the app forces re-prepare/re-verify.

- **Initialization:** **`main.dart`** calls **`FlutterGemma.initialize()`** without a HuggingFace token and wraps **`initialize`** in **`try/catch`** so a rare early plugin failure does not crash the whole app.

- **Purge ids:** **`purgeGemmaPluginInstallCandidates`** uninstalls ids derived from the **bundled asset filename**, legacy **`ikamva_ondevice_model`**, **`bundled_gemma.task`**, and related plugin install names.

- **`StubLlmEngine`:** Still selected for **`IKAMVA_USE_STUB_LLM=1`** (process **environment**, not `--dart-define`) or non-mobile hosts / `flutter test`.

### Developer / CI

- **VS Code:** **`.vscode/launch.json`** may pass **`--dart-define-from-file=${workspaceFolder}/.env`**. Use an **empty** **`.env`** if required; optional **`IKAMVA_MODEL_*`** defines adjust prepare-screen free-space hints only (`model_prepare_config.dart`).
- **GitHub Actions:** **`build-and-deploy`** ensures a repo-root **`.env`** exists (e.g. **`touch .env`**) so **`--dart-define-from-file`** succeeds; release binaries must list the **`.litertlm`** in **`pubspec.yaml`**.

### UI / diagnostics

- **Developer (`/dev/stats`):** Model tab shows **bundled asset path**; **Probe active Gemma model**, **Invalidate LLM** / **Reset model prepare**.
- **Developer (`/dev/stats`) multi-page:** tabbed diagnostics (`Overview`, `Model`, `Event Log`) with verbose model telemetry (probe/open/install/retry/purge) and copyable JSON timeline for troubleshooting.
- **Settings:** Copy updated for bundle-only weights; warm-up error snackbar points to prepare flow.

### Documentation

- **`README.md`**, **`spec.md`**, **`learner_app/README.md`**, **`OBTAINING_MODELS.txt`**, **`learner_app/docs/model_delivery.md`**, and **`CHANGELOG.md`** describe **asset-only** model delivery.
- Added tests: `model_prepare_prefs_test.dart`, `model_diagnostics_test.dart`, and `flutter_gemma_error_classification_test.dart` to harden prepare/load state and error classification regressions.

### Repository

- **Removed:** HTTP model download path, **`ModelLocalCache`**, and legacy **`learner_app/assets/models/bundled_gemma.task`** (and its **`pubspec.yaml`** asset entry) where superseded by **`.litertlm`**.
