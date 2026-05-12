import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'detailed_smart_downloader.dart';
import 'gemma_model_config.dart';
import 'hf_local_file.dart';
import 'huggingface_auth_token_store.dart';

/// Hugging Face `.litertlm` install into app documents + [DetailedSmartDownloader].
class GemmaHfModelDownloadService {
  GemmaHfModelDownloadService({
    required this.modelUrl,
    required this.modelFilename,
    required this.needsAuth,
    this.foreground,
  });

  final String modelUrl;
  final String modelFilename;
  final bool needsAuth;

  /// Android foreground download (example: `null` = auto by size).
  final bool? foreground;

  factory GemmaHfModelDownloadService.e2b() {
    return GemmaHfModelDownloadService(
      modelUrl: GemmaModelConfig.gemma4E2bLitertlmUrl,
      modelFilename: GemmaModelConfig.gemma4E2bLitertlmFilename,
      needsAuth: false,
      foreground: true,
    );
  }

  factory GemmaHfModelDownloadService.e4b() {
    return GemmaHfModelDownloadService(
      modelUrl: GemmaModelConfig.gemma4E4bLitertlmUrl,
      modelFilename: GemmaModelConfig.gemma4E4bLitertlmFilename,
      needsAuth: false,
      foreground: true,
    );
  }

  Future<String?> loadToken() => HuggingfaceAuthTokenStore.loadToken();

  String get artifactFilename {
    final uri = Uri.parse(modelUrl);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : modelFilename;
  }

  /// Fast path: model file already on disk (no HEAD).
  Future<bool> isPluginModelInstalled() async {
    if (kIsWeb) return false;
    final filePath = await getFilePath();
    return hfLocalFileExistsSync(filePath);
  }

  Future<String> getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final correctedPath = directory.path.contains('/data/user/0/')
        ? directory.path.replaceFirst('/data/user/0/', '/data/data/')
        : directory.path;
    return '$correctedPath/$modelFilename';
  }

  Future<bool> checkModelExistence(String token) async {
    try {
      if (kIsWeb) {
        return false;
      }

      final filePath = await getFilePath();
      if (!hfLocalFileExistsSync(filePath)) {
        return false;
      }

      final Map<String, String> headers =
          token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {};

      try {
        final headResponse =
            await http.head(Uri.parse(modelUrl), headers: headers);
        if (headResponse.statusCode == 200) {
          final contentLengthHeader = headResponse.headers['content-length'];
          if (contentLengthHeader != null) {
            final remoteFileSize = int.parse(contentLengthHeader);
            return await hfLocalFileLength(filePath) == remoteFileSize;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('HEAD request failed, trusting file existence: $e');
        }
        return true;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking model existence: $e');
      }
    }
    return false;
  }

  Future<void> downloadModel({
    required String token,
    required void Function(double progress) onProgress,
    void Function(String line)? onDiagnostic,
  }) async {
    final authToken = token.isEmpty ? null : token;
    final void Function(String line)? previous = DetailedSmartDownloader.onDiagnostic;
    if (onDiagnostic != null) {
      DetailedSmartDownloader.onDiagnostic = (line) {
        previous?.call(line);
        onDiagnostic(line);
      };
    }
    try {
      final targetPath = await getFilePath();
      await for (final p in DetailedSmartDownloader.downloadWithProgress(
        url: modelUrl,
        targetPath: targetPath,
        token: authToken,
        maxRetries: 10,
        foreground: foreground,
      )) {
        onProgress(p.clamp(0, 100).toDouble());
      }
    } finally {
      if (onDiagnostic != null) {
        DetailedSmartDownloader.onDiagnostic = previous;
      }
    }
  }

  Future<void> deleteModel() async {
    try {
      final path = await getFilePath();
      final f = File(path);
      if (f.existsSync()) {
        await f.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting model: $e');
      }
    }
  }
}
