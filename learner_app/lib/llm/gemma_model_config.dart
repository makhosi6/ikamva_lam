import 'package:flutter_gemma/core/utils/file_name_utils.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;

/// On-device Gemma identity for **`flutter_gemma`**.
///
/// Weights are **only** loaded from **`bundledGemma4E2bLitertlmAsset`** via
/// **`installModel`…`fromAsset`** (see `pubspec.yaml` and `OBTAINING_MODELS.txt`).
abstract final class GemmaModelConfig {
  static const ModelType modelType = ModelType.gemmaIt;

  /// Default on-device weights (Gemma 4 E2B Instruct, LiteRT LM `.litertlm`).
  static const String bundledGemma4E2bLitertlmAsset =
      'assets/models/gemma-4-E2B-it.litertlm';

  /// **`-web.task`** files are **Web-only** per the `flutter_gemma` README
  /// compatibility matrix (not for native `.litertlm` workflows).
  static bool isWebOnlyMediaPipeTaskUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.contains('-web.task');
  }

  /// Filename / artifact id derived from a URL or path (used for purge ids).
  static String filenameFromPathOrUrl(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) return segs.last;
    }
    return p.basename(trimmed.split('?').first);
  }

  /// Ids to try with [FlutterGemma.uninstallModel] when clearing bad installs.
  static List<String> pluginUninstallCandidateIdsFor(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return const [];
    final file = filenameFromPathOrUrl(pathOrUrl);
    final base = FileNameUtils.getBaseName(file);
    return <String>{file, if (base != file) base}.toList();
  }

  /// Use [ModelFileType.task] for `.task` and `.litertlm` per plugin docs.
  static ModelFileType fileTypeForPath(String assetPath) {
    final lower = assetPath.toLowerCase();
    if (lower.endsWith('.litertlm')) return ModelFileType.task;
    if (lower.endsWith('.task')) return ModelFileType.task;
    if (lower.endsWith('.bin') || lower.endsWith('.tflite')) {
      return ModelFileType.binary;
    }
    return ModelFileType.task;
  }
}
