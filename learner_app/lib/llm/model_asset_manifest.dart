import 'dart:convert';

import 'package:flutter/services.dart';

/// Whether [assetKey] appears in the Flutter asset manifest (e.g. listed in
/// `pubspec.yaml` and bundled in the build). Does **not** load the asset bytes.
Future<bool> modelAssetListedInBundle(String assetKey) async {
  if (assetKey.isEmpty) return false;
  try {
    final raw = await rootBundle.loadString('AssetManifest.json');
    final decoded = jsonDecode(raw);
    print('decoded: $decoded');
    if (decoded is! Map) return false;
    final map = Map<String, dynamic>.from(decoded);
    print('map: $map');
    if (map.containsKey(assetKey)) {
      print('containsKey: $assetKey: ${map[assetKey]}');
      return true;
    }
    if (assetKey.endsWith('/')) return false;
    return map.containsKey('$assetKey/');
  } on Object {
    return false;
  }
}
