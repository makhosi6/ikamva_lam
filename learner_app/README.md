# Ikamva Lam

**Version:** `0.0.1+1` (see [`pubspec.yaml`](pubspec.yaml) `version:`).

<img src="../branding/cover.png" alt="Ikamva Lam cover banner" width="1200" style="max-width: 100%; height: auto;" />

Ikamva Lam is a lightweight learning app that helps learners build English confidence through short, engaging micro-games. It is designed for primary and early secondary learners, especially in environments where:

- English is not the home language
- Access to books and devices is limited
- Internet connectivity is unreliable

The system keeps the **Teacher/Parent** (school or home) in control, while AI runs locally on-device to support learners with hints, feedback, and structured practice. The learner app is deliberately multimodal—animations, illustrations, and voice—so learners can listen while they read, practice speaking aloud, and use optional voice commands without everything depending on dense on-screen text alone.

One-line pitch: Ikamva Lam builds English confidence through guided play, with Teacher/Parent oversight, a rich multimodal learner interface, and fully offline AI support.

## Kokoro read-aloud

On-device neural TTS uses **Kokoro** assets committed under `assets/kokoro/`: `kokoro-v1.0.int8.onnx` and `voices_bundle.json`. No download step is required for `flutter test`, `flutter run`, or CI.

To refresh those files from upstream (e.g. after changing the bundled voice), from `learner_app/`:

```bash
bash tool/fetch_kokoro_models.sh
```

## On-device LLM (Gemma)

Gemma 4 **E2B** **`gemma-4-E2B-it.litertlm`** is **bundled** under **`assets/models/`** (see **`pubspec.yaml`**). There is **no** remote model download — see **`assets/models/OBTAINING_MODELS.txt`** and **[`docs/model_delivery.md`](docs/model_delivery.md)**.

For history and one-off release notes, see **`CHANGELOG.md`** (*Unreleased*).

### Debugging model issues

- Use `/dev/stats` in debug builds:
  - `Overview`: runtime + metrics + export/sync actions.
  - `Model`: resolved engine, prepare-state metadata, active-model probe, cache invalidation.
  - `Event Log`: verbose lifecycle timeline for model prepare/probe/load/reinstall events.
- The app persists prepare **fingerprint** (`bundle:…`) and timestamp; if the fingerprint changes, **`ensureReady()`** may run again.