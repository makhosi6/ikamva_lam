import 'package:path/path.dart' as p;

import 'on_device_gemma_variant.dart';

/// On-device Gemma identity and Hugging Face artifact URLs.
///
/// Catalog: **Gemma 3n** (E2B / E4B) and **Gemma 4** (E2B / E4B) `.litertlm`
/// bundles. Weights download into app documents, then open via native
/// **LiteRT-LM** (Android) or **MediaPipe GenAI** (iOS).
///
/// **Gemma 4 URLs** use [litert-community](https://huggingface.co/litert-community)
/// (publicly resolvable). **Gemma 3n** uses Google’s gated
/// `google/gemma-3n-*-litert-lm` repos (HF token via `IKAMVA_HF_TOKEN`).
abstract final class GemmaModelConfig {
  /// Hugging Face **Gemma 3n E2B IT** `.litertlm` (~3.1 GB). Recommended default.
  static const String gemma3nE2bLitertlmUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm';

  static String get gemma3nE2bLitertlmFilename =>
      filenameFromPathOrUrl(gemma3nE2bLitertlmUrl);

  /// Hugging Face **Gemma 3n E4B IT** `.litertlm` (~6.5 GB).
  static const String gemma3nE4bLitertlmUrl =
      'https://huggingface.co/google/gemma-3n-E4B-it-litert-lm/resolve/main/gemma-3n-E4B-it-int4.litertlm';

  static String get gemma3nE4bLitertlmFilename =>
      filenameFromPathOrUrl(gemma3nE4bLitertlmUrl);

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

  /// Resolve URL + auth flag for a catalog variant.
  static ({String url, String filename, bool needsAuth}) artifactFor(
    OnDeviceGemmaVariant variant,
  ) {
    switch (variant) {
      case OnDeviceGemmaVariant.gemma3nE2b:
        return (
          url: gemma3nE2bLitertlmUrl,
          filename: gemma3nE2bLitertlmFilename,
          needsAuth: true,
        );
      case OnDeviceGemmaVariant.gemma3nE4b:
        return (
          url: gemma3nE4bLitertlmUrl,
          filename: gemma3nE4bLitertlmFilename,
          needsAuth: true,
        );
      case OnDeviceGemmaVariant.gemma4E2b:
        return (
          url: gemma4E2bLitertlmUrl,
          filename: gemma4E2bLitertlmFilename,
          needsAuth: false,
        );
      case OnDeviceGemmaVariant.gemma4E4b:
        return (
          url: gemma4E4bLitertlmUrl,
          filename: gemma4E4bLitertlmFilename,
          needsAuth: false,
        );
    }
  }

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

  /// Whether to enable **native** vision / audio modalities when loading the
  /// `.litertlm` bundle.
  ///
  /// Gemma 3n / Gemma 4 artifacts can contain vision/audio subgraphs, but this
  /// learner app only calls [LlmService.generate] with **text**. Keeping these
  /// `false` lets LiteRT open for text-only use, honors **Low RAM** / CPU
  /// backend, and allows GPU→CPU fallback on devices that crash during heavy
  /// OpenCL init.
  ///
  /// Set to `true` only when the app passes images/audio into native inference.
  static const bool activeModelSupportImage = false;
  static const bool activeModelSupportAudio = false;
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
