# Ikamva Lam

**Release:** `v0.2.0` (learner app `0.2.0+3` in [`learner_app/pubspec.yaml`](learner_app/pubspec.yaml)).

<img src="branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

Playful, teacher-guided English practice for primary and early secondary learners. Learner app targets **offline-first** use on tablets and low-end laptops; on-device AI is planned via **llama.cpp** and quantised **Gemma 4** (see [spec.md](spec.md)).

## Repository layout

| Path | Purpose |
|------|---------|
| [branding/](branding/) | Logo & cover PNGs (raster), SVG source, future brand assets |
| [scripts/](scripts/) | e.g. `generate_cover.py` — cover layout (logo + copy) |
| [learner_app/](learner_app/) | Flutter learner client |
| [native/](native/) | Planned llama.cpp build notes and FFI bridge |
| [TASKS.md](TASKS.md) | Detailed build checklist |
| [design.md](design.md) | UX flows and visual tokens |
| [spec.md](spec.md) | Technical specification |
| [writeup.md](writeup.md) | Hackathon narrative |

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

## Models (llama.cpp + Gemma)

- Place **GGUF** weights under a gitignored path (e.g. `native/models/`); do not commit large binaries.
- Use **Q4_K_M** quantisation; prefer **Gemma 4 E2B** on ~4GB RAM and **E4B** on ~8GB where possible.
- See [native/README.md](native/README.md) for the intended FFI stack.

## License

This repository is licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). See [LICENSE](LICENSE). That matches the Gemma 4 Good Hackathon winner license type; third-party dependencies (for example Flutter packages) remain under their own licenses.

Use Gemma model weights only in line with [Google’s Gemma terms of use](https://ai.google.dev/gemma/terms) (separate from the Kaggle rules file).
