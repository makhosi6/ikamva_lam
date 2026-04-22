import 'package:flutter_gemma/flutter_gemma.dart';

import 'gemma_model_config.dart';

/// **HTTP-only** model install — compile-time `String.fromEnvironment` only.
/// Do not ship production secrets in `IKAMVA_HF_TOKEN` for public builds.
///
/// Example:
/// ```bash
/// flutter run --dart-define-from-file=.env
/// # .env contains:
/// # IKAMVA_MODEL_DOWNLOAD_URL=https://huggingface.co/.../model.task
/// # IKAMVA_HF_TOKEN=hf_...   # optional, gated repos
/// ```
abstract final class ModelPrepareConfig {
  static const String networkUrl = String.fromEnvironment(
    'IKAMVA_MODEL_DOWNLOAD_URL',
    defaultValue: '',
  );

  static const String hfToken = String.fromEnvironment(
    'IKAMVA_HF_TOKEN',
    defaultValue: '',
  );

  static bool get hasNetworkModelUrl => networkUrl.isNotEmpty;

  /// Rough download size for **free disk** checks (MB).
  static const int estimatedDownloadMb = int.fromEnvironment(
    'IKAMVA_MODEL_ESTIMATED_MB',
    defaultValue: 900,
  );

  /// Extra headroom above model size (MB) for unpack / temp files.
  static const int headroomMb = int.fromEnvironment(
    'IKAMVA_MODEL_HEADROOM_MB',
    defaultValue: 256,
  );

  /// Minimum free disk space (MB) before we warn / block installs.
  static const int minFreeDiskMb = int.fromEnvironment(
    'IKAMVA_MODEL_MIN_FREE_MB',
    defaultValue: 1024 * 2,
  );

  static ModelType get modelType => GemmaModelConfig.modelType;

  static ModelFileType fileTypeForInstallSource(String pathOrUrl) =>
      GemmaModelConfig.fileTypeForPath(pathOrUrl);
}
