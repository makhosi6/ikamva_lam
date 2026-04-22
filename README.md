# Ikamva Lam

<img src="branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

Playful, Teacher/Parent-guided English practice for primary and early secondary learners (school or home). Learner app targets **offline-first** use on tablets and low-end phones; on-device AI runs via **`flutter_gemma`** with a **one-time HTTPS download** of Gemma weights (not shipped in the APK — see [spec.md](spec.md)).

## Repository layout

| Path | Purpose |
|------|---------|
| [branding/](branding/) | Logo & cover PNGs (raster), SVG source, future brand assets |
| [scripts/](scripts/) | e.g. `generate_cover.py` — cover layout (logo + copy) |
| [learner_app/](learner_app/) | Flutter learner client |
| [learner_app/assets/models/](learner_app/assets/models/) | `OBTAINING_MODELS.txt` — how to set `IKAMVA_MODEL_DOWNLOAD_URL` (no weights in repo) |
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
| Model ready (HTTP `.task` install + first `generate`) | TBD | TBD |
| First-token latency (one cloze prompt) | TBD | TBD |
| Avg. task generation (queue fill) | TBD | TBD |

**How to capture (TASKS Phase 17.1):** (1) Note device model, OS version, RAM, and Git commit. (2) Cold start: time from app icon tap until Welcome or Hub is interactive. (3) Model ready: first successful `LlmService.generate` after the `.task` is downloaded and opened (Settings → “Warm up model” or first hub generation). (4) First-token: one representative `TASK: generate_cloze` prompt; stopwatch from invoke to first visible character if streaming is enabled, else full completion. (5) Queue fill: average wall time for `TaskQueueService` top-up of *N* items (pick N in app logs or debug panel). Paste numbers into this table and keep a copy for [writeup.md](writeup.md).

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

## Models (flutter_gemma + HTTP download)

- **Production (Android / iOS):** weights are **not** in the APK. Set **`IKAMVA_MODEL_DOWNLOAD_URL`** at compile time (HTTPS link to a **native** artifact: **`.litertlm`** for Gemma 4, or a mobile **`.task`** for older families — **never** a **`*-web.task`** URL on iOS/Android; those are Web-only and cause LiteRT “zip archive” errors). Use repo-root **`.env`** with `--dart-define-from-file=.env` (see `.env.example`) or your CI equivalent. Optional **`IKAMVA_HF_TOKEN`** for gated Hugging Face files. Full checklist: `learner_app/assets/models/OBTAINING_MODELS.txt`.
- **Persistence:** after the first successful download, `flutter_gemma` keeps the model on device; cold starts re-open it. If the file is missing or corrupt, the prepare flow or **`LlmService.ensureReady` / `generate`** triggers a **re-download**.
- **Default target:** Gemma 3 **1B**–class mobile `.task` from [litert-community](https://huggingface.co/litert-community) or similar (team choice in `docs/flutter_gemma_migration_scope.md`).
- **Pin:** `flutter_gemma` version is pinned in `learner_app/pubspec.yaml`; run `pod install` under `learner_app/ios` after upgrades.
- **Stub / CI:** `IKAMVA_USE_STUB_LLM=1` or `flutter test` on a desktop host uses **`StubLlmEngine`** (no download).
- **Privacy:** all **LLM inference is on-device**; the download URL is only used to fetch weights to the device. Optional non-LLM network (e.g. sync) is separate—see `docs/api_sync_contract.md`.
- **Optional sync:** compile with `--dart-define=IKAMVA_SYNC_URL=https://example.com/v1/summaries` to exercise outbox flush (see `docs/api_sync_contract.md`).

### VS Code, `.env`, and CI

- **Local:** copy **`.env.example`** → **`.env`** at the repo root; set at least **`IKAMVA_MODEL_DOWNLOAD_URL`** (and **`IKAMVA_HF_TOKEN`** if your URL is gated). VS Code **Run and Debug** uses **`--dart-define-from-file=${workspaceFolder}/.env`** (see **`.vscode/launch.json`**). If **`.env` is missing**, Flutter fails fast with the standard “Did not find the file passed to `--dart-define-from-file`” message — create the file first.
- **Stub LLM (tests / forced QA):** set process environment **`IKAMVA_USE_STUB_LLM=1`** (not a `dart-define` in this codebase). Launch configs do not set it by default.
- **Release builds (GitHub Actions):** the **`build-and-deploy`** job writes **`.env`** from **`secrets.IKAMVA_HF_TOKEN`** and **`secrets.IKAMVA_MODEL_DOWNLOAD_URL`** before **`flutter build apk`** / **`flutter build ios`**. Add those repository secrets for tagged releases that must embed a download URL.

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
