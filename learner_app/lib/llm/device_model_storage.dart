import 'package:flutter_gemma/flutter_gemma.dart';

import 'gemma_model_config.dart';

/// Copies bundled inference weights from the Flutter **asset pack** into
/// **on-device storage** the native runtime can open (same role as manually
/// copying a `.task` / `.litertlm` to a temp path before MediaPipe / LiteRT).
///
/// Do not load multi‑gigabyte assets with [rootBundle.load]; the plugin
/// streams the install natively.
Future<void> installBundledInferenceWeightsFromFlutterAsset({
  required String assetPath,
  required void Function(int installPercent) onProgress,
}) async {
  await FlutterGemma.installModel(
    modelType: GemmaModelConfig.modelType,
    fileType: GemmaModelConfig.fileTypeForPath(assetPath),
  ).fromAsset(assetPath).withProgress(onProgress).install();
}
