# Ikamva Lam

<img src="branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

Playful, Teacher/Parent-guided English practice for primary and early secondary learners (school or home). Learner app targets **offline-first** use on tablets and low-end phones; on-device AI runs via **`flutter_gemma`** with a **bundled** Gemma 4 E2B **`.litertlm`** (optional compile-time HTTP override — see [spec.md](spec.md)).

## Repository layout

| Path | Purpose |
|------|---------|
| [branding/](branding/) | Logo & cover PNGs (raster), SVG source, future brand assets |
| [scripts/](scripts/) | e.g. `generate_cover.py` — cover layout (logo + copy) |
| [learner_app/](learner_app/) | Flutter learner client |
| [learner_app/assets/models/](learner_app/assets/models/) | Bundled **`gemma-4-E2B-it.litertlm`** + `OBTAINING_MODELS.txt` |
| [TASKS.md](TASKS.md) | Detailed build checklist |
| [design.md](design.md) | UX flows and visual tokens |
| [spec.md](spec.md) | Technical specification |
| [writeup.md](writeup.md) | Hackathon narrative |
| [docs/api_sync_contract.md](docs/api_sync_contract.md) | Optional summary sync API (TASKS §14) |
| [DEMO.md](DEMO.md) | 90s judging script (TASKS §16.1) |
| [teacher_web/](teacher_web/) | Teacher/Parent web dashboard placeholder (TASKS §14.3) |
| [notebooks/](notebooks/) | Kaggle-friendly overview notebook (TASKS §16.4) |

## Benchmarks & devices (TASKS §15.1–15.2)

Fill this table on real hardware after profiling. Stub LLM timings are not representative of Gemma.

| Metric | 4GB RAM (E2B target) | 8GB RAM (E4B target) |
|--------|----------------------|------------------------|
| Cold start → first interactive frame | TBD | TBD |
| Model ready (bundled `.litertlm` install + first `generate`) | TBD | TBD |
| First-token latency (one cloze prompt) | TBD | TBD |
| Avg. task generation (queue fill) | TBD | TBD |

**How to capture (TASKS Phase 17.1):** (1) Note device model, OS version, RAM, and Git commit. (2) Cold start: time from app icon tap until Welcome or Hub is interactive. (3) Model ready: first successful `LlmService.generate` after bundled **`ensureReady()`** / hub warm-up finishes and the model is opened (Settings → “Warm up model” or first hub generation). (4) First-token: one representative `TASK: generate_cloze` prompt; stopwatch from invoke to first visible character if streaming is enabled, else full completion. (5) Queue fill: average wall time for `TaskQueueService` top-up of *N* items (pick N in app logs or debug panel). Paste numbers into this table and keep a copy for [writeup.md](writeup.md).

**Battery / thermal (TASKS §15.4):** run a continuous 15-minute practice session on a physical device; note % battery drop and subjective warmth in your writeup. No simulator substitute.

## Deploy demo (TASKS §14.4)

Build Flutter web or ship macOS build to judges. Example static hosting: **Firebase Hosting** or **GitHub Pages** — upload `build/web` after `flutter build web`, set SPA fallback to `index.html`, paste public URL into [writeup.md](writeup.md).

## Toolchain (pinned for the team)

- **Flutter:** 3.38.x stable (Dart 3.10+)
- **Platforms:** iOS, Android, macOS (desktop useful for local demos)

Run `flutter --version` in CI and locally; upgrade only when the team agrees.

## Run the learner app

```bash
cd learner_app
flutter pub get
flutter run
```

Target a tablet or resize the window to verify large touch targets and typography.

## Cover image (1200×630)

The welcome screen and docs use `branding/cover.png`: **logo** from `logo.png` on the **left** (same `#F6F1E7` as the logo canvas, ~one-third width), **title + tagline** on the **right** (cream panel, tight margins). Regenerate after logo changes:

```bash
python3 scripts/generate_cover.py
```

Requires **macOS** system fonts (*Arial Rounded Bold*, *Arial*). On Linux, point the script at equivalent `.ttf` paths or install those faces.

## Models (flutter_gemma + bundled `.litertlm` only)

- **Production (Android / iOS):** Gemma 4 **E2B** **`gemma-4-E2B-it.litertlm`** is **bundled** under `learner_app/assets/models/` and declared in **`pubspec.yaml`**. There is **no** HTTP download of weights; first use copies via **`FlutterGemma.installModel`…`fromAsset`**. Checklist: `learner_app/assets/models/OBTAINING_MODELS.txt`, architecture: `learner_app/docs/model_delivery.md`.
- **Persistence:** the plugin keeps the installed model on device. Cold starts re-open the active model; if it is missing or corrupt, **`LlmService.ensureReady` / `generate`** or the prepare flow can trigger a **re-install from the bundled asset**.
- **Cross-session correctness:** prepare state stores a **bundle fingerprint**. If the bundled path changes between builds, the app may route through prepare/verify so stale artifacts are not reused.
- **Default target:** Gemma 4 **E2B** `.litertlm` from [litert-community](https://huggingface.co/litert-community) (you vendor the file into `assets/models/`).
- **Pin:** `flutter_gemma` version is pinned in `learner_app/pubspec.yaml`; run `pod install` under `learner_app/ios` after upgrades.
- **Stub / CI:** `IKAMVA_USE_STUB_LLM=1` or `flutter test` on a desktop host does not load the mobile plugin for real inference.
- **Privacy:** all **LLM inference is on-device**. Optional non-LLM network (e.g. sync) is separate—see `docs/api_sync_contract.md`.
- **Optional sync:** compile with `--dart-define=IKAMVA_SYNC_URL=https://example.com/v1/summaries` to exercise outbox flush (see `docs/api_sync_contract.md`).
- **Debug diagnostics:** in debug builds, `/dev/stats` is now tabbed (`Overview`, `Model`, `Event Log`). The `Event Log` captures verbose model lifecycle events (probe/open/install/retry/purge) and supports copy-to-clipboard for bug reports.

### VS Code, `.env`, and CI

- **Local:** VS Code **Run and Debug** may use **`--dart-define-from-file=${workspaceFolder}/.env`** (see **`.vscode/launch.json`**). Gemma weights are **not** configured via `.env`; use an empty **`.env`** if the launch config requires the file. Optional **`IKAMVA_MODEL_*`** defines adjust prepare-screen free-space hints (`model_prepare_config.dart`).
- **Stub LLM (tests / forced QA):** set process environment **`IKAMVA_USE_STUB_LLM=1`** (not a `dart-define` in this codebase). Launch configs do not set it by default.
- **Release builds (GitHub Actions):** **`build-and-deploy`** creates an empty repo-root **`.env`** so **`--dart-define-from-file`** succeeds; release binaries must list the `.litertlm` in **`pubspec.yaml`**.

### Minimum device profile (on-device Gemma)

- **RAM:** target **≥ 4 GB** for Gemma 3 **1B**–class `.task` weights; enable **Low RAM** in Settings on weaker devices (smaller context, CPU preference).
- **OS:** **iOS 16+** (see `learner_app/ios/Podfile`); Android — use a recent 64-bit device/emulator compatible with the `flutter_gemma` / MediaPipe stack.
- **Below minimum:** model prepare or inference may fail; the app shows errors — there is **no** cloud LLM fallback.

### Maintainer dependency upgrades (`flutter_gemma`)

1. Bump the **exact** version in `learner_app/pubspec.yaml` and run `flutter pub get`.
2. Re-read the [flutter_gemma changelog](https://pub.dev/packages/flutter_gemma/changelog) for iOS `Podfile` / Android manifest notes.
3. Run `cd learner_app/ios && pod install` and verify `flutter build apk` / `flutter build ios`.

## License

This repository is licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). See [LICENSE](LICENSE). That matches the Gemma 4 Good Hackathon winner license type; third-party dependencies (for example Flutter packages) remain under their own licenses.

Use Gemma model weights only in line with [Google’s Gemma terms of use](https://ai.google.dev/gemma/terms) (separate from the Kaggle rules file).
