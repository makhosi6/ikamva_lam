import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/model_management/cancel_token.dart';
import 'package:flutter_gemma/core/utils/file_name_utils.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stable on-disk location for HTTP-fetched weights before
/// `FlutterGemma.installModel(…).fromFile(…)`.
///
/// Using one fixed path (plus a sidecar meta file) makes it trivial to check
/// whether the bytes for the current compile-time URL are already present.
abstract final class ModelLocalCache {
  /// Basename must use a [FileNameUtils.supportedExtensions] suffix so the
  /// plugin derives a stable model id via [FileNameUtils.getBaseName].
  static const String localWeightsBasename = 'ikamva_ondevice_model.bin';

  static const String _metaBasename = 'ikamva_ondevice_model.meta.json';

  /// Model id used by `flutter_gemma` when installing from [localWeightsFile].
  static String get pluginModelId =>
      FileNameUtils.getBaseName(localWeightsBasename);

  static Future<Directory> _cacheDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'ikamva_gemma'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Absolute path to the canonical weights file (same path every install).
  static Future<File> localWeightsFile() async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, localWeightsBasename));
  }

  static Future<File> _metaFile() async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, _metaBasename));
  }

  /// Whether [file] exists, is non-trivial in size, and meta URL matches [url].
  @visibleForTesting
  static bool isUsableCacheForUrl({
    required String url,
    required String? metaJson,
    required int fileLength,
  }) {
    if (url.isEmpty) return false;
    if (metaJson == null || metaJson.isEmpty) return false;
    if (!FileNameUtils.isFileValid(localWeightsBasename, fileLength)) {
      return false;
    }
    try {
      final decoded = jsonDecode(metaJson);
      if (decoded is! Map<String, dynamic>) return false;
      final cachedUrl = decoded['url'];
      if (cachedUrl is! String || cachedUrl != url) return false;
      return true;
    } on Object {
      return false;
    }
  }

  static Future<bool> localFileMatchesConfiguredUrl(String url) async {
    if (url.isEmpty) return false;
    final file = await localWeightsFile();
    final meta = await _metaFile();
    if (!await file.exists() || !await meta.exists()) return false;
    try {
      final len = await file.length();
      final metaJson = await meta.readAsString();
      return isUsableCacheForUrl(url: url, metaJson: metaJson, fileLength: len);
    } on Object {
      return false;
    }
  }

  /// Deletes canonical weights + meta (e.g. corruption / URL change / purge).
  static Future<void> deleteLocalCache() async {
    final file = await localWeightsFile();
    final meta = await _metaFile();
    for (final f in [file, meta]) {
      try {
        if (await f.exists()) await f.delete();
      } on Object {
        // best-effort
      }
    }
  }

  static Future<void> downloadWeightsToCache({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();

    final file = await localWeightsFile();
    final meta = await _metaFile();
    final partPath = '${file.path}.part';
    final part = File(partPath);
    try {
      if (await part.exists()) await part.delete();
    } on Object {
      // ignore
    }

    final uri = Uri.parse(url);
    final req = http.Request('GET', uri);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    final client = http.Client();
    try {
      final streamed = await client.send(req);
      cancelToken?.throwIfCancelled();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final preview = await streamed.stream.bytesToString().catchError(
          (_) => '',
        );
        throw HttpException(
          'Model download failed (HTTP ${streamed.statusCode}): '
          '${preview.length > 240 ? preview.substring(0, 240) : preview}',
        );
      }

      final total = streamed.contentLength;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in streamed.stream) {
          cancelToken?.throwIfCancelled();
          sink.add(chunk);
          received += chunk.length;
          if (onProgress != null && total != null && total > 0) {
            onProgress((received * 100 ~/ total).clamp(0, 99));
          }
        }
      } finally {
        await sink.close();
      }

      cancelToken?.throwIfCancelled();

      if (total != null && total > 0 && received != total) {
        throw HttpException(
          'Incomplete download (size mismatch with Content-Length).',
        );
      }

      if (!FileNameUtils.isFileValid(localWeightsBasename, received)) {
        throw HttpException(
          'Downloaded model is too small ($received bytes) — '
          'check `IKAMVA_MODEL_DOWNLOAD_URL` and network.',
        );
      }

      if (await file.exists()) {
        await file.delete();
      }
      await part.rename(file.path);

      await meta.writeAsString(
        jsonEncode(<String, Object?>{'url': url, 'bytes': received}),
      );
      onProgress?.call(100);
    } on Object {
      try {
        if (await part.exists()) await part.delete();
      } on Object {
        // ignore
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Ensures [localWeightsFile] exists and matches [url]; downloads if needed.
  static Future<void> ensureLocalFileForUrl({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (await localFileMatchesConfiguredUrl(url)) {
      onProgress?.call(100);
      return;
    }
    await downloadWeightsToCache(
      url: url,
      token: token,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
