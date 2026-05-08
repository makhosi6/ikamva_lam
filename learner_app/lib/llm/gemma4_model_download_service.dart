import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'gemma_model_config.dart';

/// Network install for **Gemma 4 E4B** only (parity with `learner_app/example`).
abstract final class Gemma4ModelDownloadService {
  static Future<bool> isE4bInstalled() async {
    try {
      return FlutterGemma.isModelInstalled(
        GemmaModelConfig.gemma4E4bLitertlmFilename,
      );
    } on Object catch (e) {
      debugPrint('Gemma4ModelDownloadService.isE4bInstalled: $e');
      return false;
    }
  }

  static Future<void> downloadE4b(void Function(double percent) onProgress) async {
    await FlutterGemma.installModel(
      modelType: GemmaModelConfig.modelType,
      fileType: ModelFileType.litertlm,
    )
        .fromNetwork(
          GemmaModelConfig.gemma4E4bLitertlmUrl,
          token: null,
          foreground: null,
        )
        .withProgress((progress) => onProgress(progress.toDouble()))
        .install();
  }
}
