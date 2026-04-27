import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether [assetKey] appears in the Flutter asset manifest (e.g. listed in
/// `pubspec.yaml` and bundled in the build). Does **not** load the asset bytes.
///
/// Never call [AssetBundle.load] for multi‑gigabyte weights: Dart caps
/// [ByteData] / external typed data at ~1 GiB, which triggers
/// `NewExternalTypedData expects argument 'length' to be in the range [0..1073741823]`.
Future<bool> modelAssetListedInBundle(String assetKey) async {
  if (assetKey.isEmpty) return false;
  debugPrint('modelAssetListedInBundle: $assetKey');
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final exists = manifest.getAssetVariants(assetKey) != null;
    debugPrint('modelAssetListedInBundle: $exists');
    return exists;
  } on Object catch (e) {
    debugPrint('modelAssetListedInBundle: false ($e)');
    return false;
  }
}
