import 'package:flutter_gemma/flutter_gemma.dart';

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

  static ModelType get modelType => GemmaModelConfig.modelType;

  static String get bundledModelAssetPath =>
      GemmaModelConfig.bundledGemma4E2bLitertlmAsset;

  /// [ModelPreparePrefs] identity (bundled path only).
  static String get modelInstallFingerprint =>
      'bundle:$bundledModelAssetPath';

  static ModelFileType fileTypeForInstallSource(String pathOrUrl) =>
      GemmaModelConfig.fileTypeForPath(pathOrUrl);
}
