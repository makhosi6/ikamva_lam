/// Which on-device Gemma artifact the learner app uses.
///
/// Supports **Gemma 3n** (multimodal-capable) and **Gemma 4** LiteRT-LM
/// bundles downloaded from Hugging Face. See `docs/model_delivery.md`.
enum OnDeviceGemmaVariant {
  /// **Gemma 3n E2B IT** `.litertlm` (~3.1 GB). Recommended default — solid
  /// text quality on mid-range phones; vision/audio available when enabled.
  gemma3nE2b,

  /// **Gemma 3n E4B IT** `.litertlm` (~6.5 GB). Stronger multimodal; needs
  /// more RAM/storage.
  gemma3nE4b,

  /// **Gemma 4 E2B IT** `.litertlm` (~2.6 GB). Hackathon LiteRT prize target;
  /// text-first; may need CPU backend on mid-range GPUs.
  gemma4E2b,

  /// **Gemma 4 E4B IT** `.litertlm` (~4.3 GB). Larger Gemma 4; stronger devices.
  gemma4E4b,
}

/// Parses a persisted variant name, including legacy `Gemma4OnDeviceVariant` keys.
OnDeviceGemmaVariant? onDeviceGemmaVariantFromName(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  switch (raw) {
    case 'e2bHuggingFace':
    case 'e2bBundled':
    case 'gemma4E2b':
      return OnDeviceGemmaVariant.gemma4E2b;
    case 'e4bNetwork':
    case 'gemma4E4b':
      return OnDeviceGemmaVariant.gemma4E4b;
    case 'gemma3nE2b':
      return OnDeviceGemmaVariant.gemma3nE2b;
    case 'gemma3nE4b':
      return OnDeviceGemmaVariant.gemma3nE4b;
  }
  for (final v in OnDeviceGemmaVariant.values) {
    if (v.name == raw) return v;
  }
  return null;
}

/// Short learner-facing label for Settings / debug.
String onDeviceGemmaVariantLabel(OnDeviceGemmaVariant v) {
  return switch (v) {
    OnDeviceGemmaVariant.gemma3nE2b => 'Gemma 3n E2B (recommended)',
    OnDeviceGemmaVariant.gemma3nE4b => 'Gemma 3n E4B',
    OnDeviceGemmaVariant.gemma4E2b => 'Gemma 4 E2B',
    OnDeviceGemmaVariant.gemma4E4b => 'Gemma 4 E4B',
  };
}

/// Whether this Hugging Face repo typically requires an access token.
bool onDeviceGemmaVariantNeedsAuth(OnDeviceGemmaVariant v) {
  return switch (v) {
    OnDeviceGemmaVariant.gemma3nE2b ||
    OnDeviceGemmaVariant.gemma3nE4b =>
      true,
    OnDeviceGemmaVariant.gemma4E2b ||
    OnDeviceGemmaVariant.gemma4E4b =>
      false,
  };
}

/// @nodoc Legacy alias — prefer [OnDeviceGemmaVariant].
typedef Gemma4OnDeviceVariant = OnDeviceGemmaVariant;

/// @nodoc Legacy parser alias.
OnDeviceGemmaVariant? gemma4OnDeviceVariantFromName(String? raw) =>
    onDeviceGemmaVariantFromName(raw);
