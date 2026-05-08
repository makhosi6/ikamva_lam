import 'package:flutter_gemma/flutter_gemma.dart';

import 'gemma4_ondevice_variant.dart';
import 'gemma_model_config.dart';

/// Bundled Gemma weights only — no remote download. The `.litertlm` must be
/// listed under `flutter: assets:` in `pubspec.yaml`.
abstract final class ModelPrepareConfig {
  /// Rough **install** size for **free disk** checks (MB) — copy from APK/IPA.
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

  /// Context window passed to [FlutterGemma.getActiveModel] (`maxTokens`).
  ///
  /// Low RAM stays at 512. Otherwise uses `IKAMVA_CONTEXT_MAX_TOKENS` (512–2048;
  /// default 1024). Set `--dart-define=IKAMVA_CONTEXT_MAX_TOKENS=2048` to match
  /// common on-device chat examples that use a 2048 window (heavier RAM use).
  static int contextMaxTokensFor(bool lowRamProfile) {
    if (lowRamProfile) return 512;
    const v = int.fromEnvironment(
      'IKAMVA_CONTEXT_MAX_TOKENS',
      defaultValue: 1024,
    );
    if (v < 512) return 512;
    if (v > 2048) return 2048;
    return v;
  }

  static ModelType get modelType => GemmaModelConfig.modelType;

  static String get bundledModelAssetPath =>
      GemmaModelConfig.bundledGemma4E2bLitertlmAsset;

  /// [ModelPreparePrefs] identity for the active Gemma 4 variant.
  static String installFingerprint(Gemma4OnDeviceVariant variant) {
    switch (variant) {
      case Gemma4OnDeviceVariant.e2bBundled:
        return 'bundle:$bundledModelAssetPath';
      case Gemma4OnDeviceVariant.e4bNetwork:
        return 'network:${GemmaModelConfig.gemma4E4bLitertlmUrl}';
    }
  }

  /// Rough install / copy size for UX (MB).
  static int estimatedInstallMbFor(Gemma4OnDeviceVariant variant) {
    switch (variant) {
      case Gemma4OnDeviceVariant.e2bBundled:
        return estimatedDownloadMb;
      case Gemma4OnDeviceVariant.e4bNetwork:
        return 4400;
    }
  }

  static ModelFileType fileTypeForInstallSource(String pathOrUrl) =>
      GemmaModelConfig.fileTypeForPath(pathOrUrl);
}
