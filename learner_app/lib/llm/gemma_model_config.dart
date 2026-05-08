import 'package:flutter_gemma/core/utils/file_name_utils.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;

/// On-device **Gemma 4** identity for **`flutter_gemma`**.
///
/// This app targets **only** Gemma 4 `.litertlm` installed from Hugging Face
/// (**E2B** or **E4B** via `fromNetwork`). Other model families are not used.
///
/// E2B uses **`gemma4E2bLitertlmUrl`**; E4B uses **`gemma4E4bLitertlmUrl`**.
abstract final class GemmaModelConfig {
  /// **Gemma 4** `.litertlm` on **flutter_gemma 0.13.6** still registers as
  /// [ModelType.gemmaIt]. Newer plugin versions expose [ModelType.gemma4] (see
  /// `learner_app/example` when using a path dependency).
  static const ModelType modelType = ModelType.gemmaIt;

  /// Hugging Face **Gemma 4 E2B IT** `.litertlm` (same URL as flutter_gemma example).
  static const String gemma4E2bLitertlmUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static String get gemma4E2bLitertlmFilename =>
      filenameFromPathOrUrl(gemma4E2bLitertlmUrl);

  /// Hugging Face **Gemma 4 E4B IT** native `.litertlm` (same URL as flutter_gemma example).
  static const String gemma4E4bLitertlmUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm';

  static String get gemma4E4bLitertlmFilename =>
      filenameFromPathOrUrl(gemma4E4bLitertlmUrl);

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

  /// Runtime flags for [FlutterGemma.getActiveModel] on **Gemma 4** `.litertlm`.
  ///
  /// Must match the multimodal setup in `learner_app/_example_bak` (`Model.gemma4_E2B` /
  /// `gemma4_E4B`): vision + audio buffers are provisioned at open time.
  static const bool activeModelSupportImage = true;

  static const bool activeModelSupportAudio = true;

  static const int activeModelMaxNumImages = 1;

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
