# Changelog

## Unreleased

### Changed

- **Wrong URL guard:** URLs containing **`-web.task`** are rejected on **iOS/Android** before download (they are **Web-only** per `flutter_gemma` and trigger LiteRT “Unable to open zip archive”). Use **`.litertlm`** for Gemma 4 (e.g. `gemma-4-E2B-it.litertlm`) or a mobile **`.task`** for older families — see `OBTAINING_MODELS.txt`. Example VS Code launch URL updated accordingly.

- **LLM stack:** Replaced the `llama-cli` / GGUF subprocess path with **`flutter_gemma`** on Android and iOS. **`ProcessLlmEngine`** and the **`native/`** tree are removed.
- **Model delivery (no APK weights):** Gemma **`.task`** files are **not** bundled under `assets/`. Production mobile builds use **`FlutterGemma.installModel`…`fromNetwork`** with compile-time **`IKAMVA_MODEL_DOWNLOAD_URL`** (and optional **`IKAMVA_HF_TOKEN`**). See `learner_app/assets/models/OBTAINING_MODELS.txt`, repo-root **`.env.example`**, and README “Models”.
- **Persistence & recovery:** After a successful download, the plugin keeps the model on disk; **`getActiveModel`** is preferred on load. **`FlutterGemmaLlmEngine.ensureLoaded`** tries open → purge stale ids → re-download if needed (same when **`LlmService.generate` / `tryOpenGenerateStream` / `ensureReady`** runs, e.g. hub, task queue, settings warm-up). **`LlmService.ensureReady`** timeout increased to **600s** for large downloads.
- **Cold start / prepare:** **`probeFlutterGemmaActiveModelReady`** verifies the engine can open the active model (with **`model.close()`** errors ignored). **`SplashScreen`** sends users to **`/model-prepare`** when the prepare flag is false **or** the probe fails (clears stale prefs). **`ModelPrepareScreen`** requires a non-empty download URL, shows progress, tries **`getActiveModel`** before downloading, and handles **LiteRT “zip archive”** style failures with **`purgeGemmaPluginInstallCandidates`** + clear messaging. Layout: no **`Spacer`** inside scrollable **`ConstrainedContent`** (uses fixed spacing); **`ConstrainedContent(scrollable: false)`** on **Developer** stats where a **`ListView`** is the primary scroller.
- **Initialization:** **`main.dart`** calls **`FlutterGemma.initialize(huggingFaceToken: …)`** from **`ModelPrepareConfig`** when set, and wraps **`initialize`** in **`try/catch`** so a rare early plugin failure does not crash the whole app.
- **Purge ids:** **`purgeGemmaPluginInstallCandidates`** uninstalls ids derived from the configured URL plus legacy **`bundled_gemma.task`** for upgrades from older builds.
- **`StubLlmEngine`:** Still selected for **`IKAMVA_USE_STUB_LLM=1`** (process **environment**, not `--dart-define`) or non-mobile hosts / `flutter test`.

### Developer / CI

- **VS Code:** **`.vscode/launch.json`** passes **`--dart-define-from-file=${workspaceFolder}/.env`** for debug/profile/release. Optional config **“ikamva_lam (debug, example HF URL in launch)”** inlines an example **`IKAMVA_MODEL_DOWNLOAD_URL`** and size defines. No stub-LLM launch profile unless you set **`IKAMVA_USE_STUB_LLM`** in the shell environment yourself.
- **`.gitignore` / `.env.example`:** Tracked **`.env.example`** lists **`IKAMVA_HF_TOKEN`** and **`IKAMVA_MODEL_DOWNLOAD_URL`**; **`!.env.example`** keeps it visible while **`.env`** stays ignored.
- **GitHub Actions:** **`build-and-deploy`** writes repo-root **`.env`** with **`IKAMVA_HF_TOKEN`** and **`IKAMVA_MODEL_DOWNLOAD_URL`** from **`secrets.*`** before **`flutter build`** with **`--dart-define-from-file`**.

### UI / diagnostics

- **Developer (`/dev/stats`):** Shows **`IKAMVA_MODEL_DOWNLOAD_URL`** preview (configured / empty), **Probe active Gemma model** button (uses **`probeFlutterGemmaActiveModelReady`**), **Invalidate LLM** / **Reset model prepare**; removed bundled-asset byte probe.
- **Settings:** Copy updated for HTTP-only weights; warm-up error snackbar points to download URL / prepare flow.

### Documentation

- **`README.md`**, **`TASKS.md`**, **`spec.md`**, **`writeup.md`**, **`docs/flutter_gemma_migration_scope.md`**, **`docs/flutter_gemma_migration_tasks.md`**, **`notebooks/hackathon_overview.ipynb`**, and **`CHANGELOG.md`** aligned with HTTP-only delivery, CI secrets, and behaviour above. Scope **§7 / §8 / §9** updated where they previously assumed bundled weights.

### Repository

- **Removed:** `learner_app/assets/models/bundled_gemma.task` and its **`pubspec.yaml`** asset entry.
