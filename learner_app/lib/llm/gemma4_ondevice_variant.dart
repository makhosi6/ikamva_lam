/// Which **Gemma 4** on-device artifact the learner app uses (see `docs/plan-gemma4-model-selection.md`).
enum Gemma4OnDeviceVariant {
  /// **Gemma 4 E2B IT** from Hugging Face (`fromNetwork`, example [ModelDownloadService]).
  e2bHuggingFace,

  /// **Gemma 4 E4B IT** `.litertlm` from Hugging Face (`fromNetwork`).
  e4bNetwork,
}

Gemma4OnDeviceVariant? gemma4OnDeviceVariantFromName(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final v in Gemma4OnDeviceVariant.values) {
    if (v.name == raw) return v;
  }
  return null;
}
