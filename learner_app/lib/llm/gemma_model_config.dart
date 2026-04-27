import 'package:flutter_gemma/core/utils/file_name_utils.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;

/// On-device **Gemma 4** identity for **`flutter_gemma`**.
///
/// This app targets **only** Gemma 4 E2B (bundled `.litertlm`). Other model
/// families are not installed or selected.
///
/// Weights load from **`bundledGemma4E2bLitertlmAsset`** via
/// **`FlutterGemma.installModel`…`fromAsset`** (see `pubspec.yaml`).
abstract final class GemmaModelConfig {
  /// Gemma 4 uses the shared Gemma instruction-tuned type (per plugin table).
  static const ModelType modelType = ModelType.gemmaIt;

  /// Gemma 4 E2B Instruct — LiteRT-LM **`.litertlm`** (Android + iOS).
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

  /// **`.litertlm`** must use [ModelFileType.litertlm] so LiteRT-LM paths,
  /// native `systemInstruction`, and chat templating match the plugin (Gemma 4).
  /// **`.task`** uses [ModelFileType.task] (older MediaPipe mobile artifacts).
  static ModelFileType fileTypeForPath(String assetPath) {
    final lower = assetPath.toLowerCase();
    if (lower.endsWith('.litertlm')) return ModelFileType.litertlm;
    if (lower.endsWith('.task')) return ModelFileType.task;
    if (lower.endsWith('.bin') || lower.endsWith('.tflite')) {
      return ModelFileType.binary;
    }
    return ModelFileType.task;
  }
}
