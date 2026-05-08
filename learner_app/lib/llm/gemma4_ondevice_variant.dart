/// Which **Gemma 4** on-device artifact the learner app uses (see `docs/plan-gemma4-model-selection.md`).
enum Gemma4OnDeviceVariant {
  /// Bundled **Gemma 4 E2B IT** `.litertlm` from app assets (no download).
  e2bBundled,

  /// **Gemma 4 E4B IT** `.litertlm` installed via `FlutterGemma.installModel` from network.
  e4bNetwork,
}

Gemma4OnDeviceVariant? gemma4OnDeviceVariantFromName(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final v in Gemma4OnDeviceVariant.values) {
    if (v.name == raw) return v;
  }
  return null;
}
