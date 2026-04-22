import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/utils/file_name_utils.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;

/// On-device Gemma identity for **`flutter_gemma`** (network install only — no
/// weights are shipped inside the APK/IPA).
///
/// See `assets/models/OBTAINING_MODELS.txt` for how to pick a `.litertlm` /
/// mobile `.task` URL and compile with `--dart-define=IKAMVA_MODEL_DOWNLOAD_URL=…`.
abstract final class GemmaModelConfig {
  static const ModelType modelType = ModelType.gemmaIt;

  /// **`-web.task`** files are **Web-only** per the `flutter_gemma` README
  /// compatibility matrix; iOS/Android LiteRT fails with “Unable to open zip
  /// archive” if you download them for native.
  static bool isWebOnlyMediaPipeTaskUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.contains('-web.task');
  }

  /// Explains why [url] cannot be used on Android/iOS, or `null` if allowed.
  static String? mobileModelUrlBlockedReason(String url) {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    if (!isWebOnlyMediaPipeTaskUrl(url)) return null;
    return 'IKAMVA_MODEL_DOWNLOAD_URL points to a **-web.task** file, which is '
        '**Web-only** in flutter_gemma (not valid on iOS/Android). Use a '
        '**.litertlm** link for Gemma 4 (e.g. `…/gemma-4-E2B-it.litertlm` on the '
        'same Hugging Face repo) or a mobile **.task** for Gemma 3 / older '
        'families. Then delete the bad install: uninstall the app or use '
        'Developer → reset model prepare. See assets/models/OBTAINING_MODELS.txt.';
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
