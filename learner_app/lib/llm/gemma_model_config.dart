import 'package:path/path.dart' as p;

/// On-device **Gemma 4** identity and Hugging Face artifact URLs.
///
/// This app targets **only** Gemma 4 `.litertlm` installed from Hugging Face
/// (**E2B** or **E4B**). Weights are written to app documents, then opened via
/// native **LiteRT-LM** (Android `.litertlm`) or **MediaPipe GenAI** (iOS).
///
/// **URLs:** We use [litert-community](https://huggingface.co/litert-community)
/// `*-litert-lm` repos — same **Gemma 4** weights as
/// [google/gemma-4-E2B-it](https://huggingface.co/google/gemma-4-E2B-it) /
/// [google/gemma-4-E4B](https://huggingface.co/google/gemma-4-E4B), packaged for
/// LiteRT-LM and **publicly resolvable** for `background_downloader` (Google’s
/// matching `google/gemma-4-*-litert-lm` LFS blobs are often gated).
abstract final class GemmaModelConfig {
  /// Hugging Face **Gemma 4 E2B IT** `.litertlm` (LiteRT-LM bundle, ~2.6 GB).
  ///
  /// Artifact: `gemma-4-E2B-it.litertlm` on `main` (not `*-int4.litertlm`).
  static const String gemma4E2bLitertlmUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static String get gemma4E2bLitertlmFilename =>
      filenameFromPathOrUrl(gemma4E2bLitertlmUrl);

  /// Hugging Face **Gemma 4 E4B IT** `.litertlm` (LiteRT-LM bundle).
  static const String gemma4E4bLitertlmUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm';

  static String get gemma4E4bLitertlmFilename =>
      filenameFromPathOrUrl(gemma4E4bLitertlmUrl);

  /// **`-web.task`** files are **Web-only** (not for native `.litertlm` workflows).
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

  /// Basenames and stem variants to delete when clearing bad installs.
  static List<String> pluginUninstallCandidateIdsFor(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return const [];
    final file = filenameFromPathOrUrl(pathOrUrl);
    final base = p.basenameWithoutExtension(file);
    return <String>{file, if (base != file) base}.toList();
  }

  /// Runtime flags for multimodal Gemma 4 `.litertlm` (vision + audio).
  static const bool activeModelSupportImage = true;
  static const bool activeModelSupportAudio = true;
  static const int activeModelMaxNumImages = 1;

  /// File kind for install-source strings (disk / URL paths).
  static InstallModelFileKind fileKindForPath(String assetPath) {
    final lower = assetPath.toLowerCase();
    if (lower.endsWith('.litertlm')) return InstallModelFileKind.litertlm;
    if (lower.endsWith('.task')) return InstallModelFileKind.task;
    if (lower.endsWith('.bin') || lower.endsWith('.tflite')) {
      return InstallModelFileKind.binary;
    }
    return InstallModelFileKind.task;
  }
}

enum InstallModelFileKind { litertlm, task, binary }
