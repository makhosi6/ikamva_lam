import 'gemma4_ondevice_variant.dart';
import 'gemma_model_config.dart';

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

  /// [ModelPreparePrefs] identity for the active Gemma 4 variant.
  static String installFingerprint(Gemma4OnDeviceVariant variant) {
    switch (variant) {
      case Gemma4OnDeviceVariant.e2bHuggingFace:
        return 'network:${GemmaModelConfig.gemma4E2bLitertlmUrl}';
      case Gemma4OnDeviceVariant.e4bNetwork:
        return 'network:${GemmaModelConfig.gemma4E4bLitertlmUrl}';
    }
  }

  static int estimatedInstallMbFor(Gemma4OnDeviceVariant variant) {
    switch (variant) {
      case Gemma4OnDeviceVariant.e2bHuggingFace:
        return 2400;
      case Gemma4OnDeviceVariant.e4bNetwork:
        return 4400;
    }
  }

  static InstallModelFileKind fileTypeForInstallSource(String pathOrUrl) =>
      GemmaModelConfig.fileKindForPath(pathOrUrl);
}
