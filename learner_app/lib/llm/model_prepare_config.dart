import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'host_is_android.dart';
import 'gemma_model_config.dart';
import 'on_device_gemma_variant.dart';

/// On-device Gemma install sizing / fingerprints (weights come from Hugging Face).
abstract final class ModelPrepareConfig {
  static const int estimatedDownloadMb = int.fromEnvironment(
    'IKAMVA_MODEL_ESTIMATED_MB',
    defaultValue: 2048,
  );

  static const int headroomMb = int.fromEnvironment(
    'IKAMVA_MODEL_HEADROOM_MB',
    defaultValue: 256,
  );

  static const int minFreeDiskMb = int.fromEnvironment(
    'IKAMVA_MODEL_MIN_FREE_MB',
    defaultValue: 1024 * 2,
  );

  /// Context window passed to native load (`maxTokens`).
  ///
  /// **Android CPU backend ladder** (NDJSON session 669518 — MIUI device):
  ///   768 → `Failed to invoke the compiled model` → capped to 512.
  ///   512 → XNNPack `DYNAMIC_UPDATE_SLICE` node 1164 at inference time
  ///         (`RunPrefillAsync` + `nativeSendMessage`).
  ///   256 → **worse**: DYNAMIC_UPDATE_SLICE node 2122 fails during
  ///         `Engine.initialize()` (load_failed, before any inference).
  ///         A smaller KV-cache makes XNNPack graph preparation fail earlier.
  ///   → GPU (`IKAMVA_PREFER_ANDROID_GPU=true`) is the only working path.
  static int contextMaxTokensFor(bool lowRamProfile) {
    if (lowRamProfile) return 512;
    const v = int.fromEnvironment(
      'IKAMVA_CONTEXT_MAX_TOKENS',
      defaultValue: 1024,
    );
    var t = v;
    if (t < 512) return 512;
    if (t > 2048) t = 2048;
    if (!kIsWeb &&
        (hostIsAndroid || defaultTargetPlatform == TargetPlatform.android)) {
      // Keep native max aligned with [LlmLimits.clampContext] on Android (512).
      // 768 still hit LiteRT "Failed to invoke the compiled model" on some
      // devices (NDJSON session 669518 post-768-cap).
      if (t > 512) t = 512;
    }
    return t;
  }

  /// [ModelPreparePrefs] identity for the active on-device variant.
  static String installFingerprint(OnDeviceGemmaVariant variant) {
    final a = GemmaModelConfig.artifactFor(variant);
    return 'network:${a.url}';
  }

  static int estimatedInstallMbFor(OnDeviceGemmaVariant variant) {
    return switch (variant) {
      OnDeviceGemmaVariant.gemma3nE2b => 3200,
      OnDeviceGemmaVariant.gemma3nE4b => 6700,
      OnDeviceGemmaVariant.gemma4E2b => 2400,
      OnDeviceGemmaVariant.gemma4E4b => 4400,
    };
  }

  static InstallModelFileKind fileTypeForInstallSource(String pathOrUrl) =>
      GemmaModelConfig.fileKindForPath(pathOrUrl);
}
