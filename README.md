# Ikamva Lam

Playful, teacher-guided English practice for primary and early secondary learners. Learner app targets **offline-first** use on tablets and low-end laptops; on-device AI is planned via **llama.cpp** and quantised **Gemma 4** (see [spec.md](spec.md)).

## Repository layout

| Path | Purpose |
|------|---------|
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

## Models (llama.cpp + Gemma)

- Place **GGUF** weights under a gitignored path (e.g. `native/models/`); do not commit large binaries.
- Use **Q4_K_M** quantisation; prefer **Gemma 4 E2B** on ~4GB RAM and **E4B** on ~8GB where possible.
- See [native/README.md](native/README.md) for the intended FFI stack.

## License

See [LICENSE](LICENSE).
