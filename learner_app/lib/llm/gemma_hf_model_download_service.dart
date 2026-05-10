import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'detailed_smart_downloader.dart';
import 'gemma_model_config.dart';
import 'hf_local_file.dart';
import 'huggingface_auth_token_store.dart';

/// Port of `flutter_gemma_example/lib/services/model_download_service.dart` for
/// Gemma 4 `.litertlm` installs from Hugging Face (`fromNetwork` + progress).
class GemmaHfModelDownloadService {
  GemmaHfModelDownloadService({
    required this.modelUrl,
    required this.modelFilename,
    required this.licenseUrl,
    required this.modelType,
    required this.needsAuth,
    this.fileType = ModelFileType.litertlm,
    this.foreground,
  });

  final String modelUrl;
  final String modelFilename;
  final String licenseUrl;
  final ModelType modelType;
  final ModelFileType fileType;
  final bool needsAuth;

  /// Android foreground download (example: `null` = auto by size).
  final bool? foreground;

  /// Same HF artifact as `Model.gemma4_E2B` in `learner_app/_example_bak` — there,
  /// the example passes `foreground: true` for >500MB models. Match that on Android
  /// so large HF pulls are not capped by background WorkManager time limits.
  factory GemmaHfModelDownloadService.e2b() {
    return GemmaHfModelDownloadService(
      modelUrl: GemmaModelConfig.gemma4E2bLitertlmUrl,
      modelFilename: GemmaModelConfig.gemma4E2bLitertlmFilename,
      licenseUrl: '',
      modelType: GemmaModelConfig.modelType,
      needsAuth: false,
      fileType: ModelFileType.litertlm,
      foreground: true,
    );
  }

  /// Same pattern as `Model.gemma4_E4B` in the flutter_gemma example (large → foreground).
  factory GemmaHfModelDownloadService.e4b() {
    return GemmaHfModelDownloadService(
      modelUrl: GemmaModelConfig.gemma4E4bLitertlmUrl,
      modelFilename: GemmaModelConfig.gemma4E4bLitertlmFilename,
      licenseUrl: '',
      modelType: GemmaModelConfig.modelType,
      needsAuth: false,
      fileType: ModelFileType.litertlm,
      foreground: true,
    );
  }

  Future<String?> loadToken() => HuggingfaceAuthTokenStore.loadToken();

  /// Same basename as [FlutterGemma.installModel] / repository (example `ModelDownloadService`).
  String get artifactFilename {
    final uri = Uri.parse(modelUrl);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : modelFilename;
  }

  /// Fast path: plugin registry only (no filesystem / HEAD), matches example before install.
  Future<bool> isPluginModelInstalled() =>
      FlutterGemma.isModelInstalled(artifactFilename);

  Future<String> getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final correctedPath = directory.path.contains('/data/user/0/')
        ? directory.path.replaceFirst('/data/user/0/', '/data/data/')
        : directory.path;
    return '$correctedPath/$modelFilename';
  }

  /// Example: [FlutterGemma.isModelInstalled], then optional filesystem + HEAD.
  Future<bool> checkModelExistence(String token) async {
    try {
      if (await isPluginModelInstalled()) {
        return true;
      }

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
      final chain = FlutterGemma.installModel(
        modelType: modelType,
        fileType: fileType,
      ).fromNetwork(
        modelUrl,
        token: authToken,
        foreground: foreground,
      );
      // Example `ChatScreen` / `ModelDownloadService`: install() is idempotent and
      // skips transfer when already registered — avoid progress plumbing when fast.
      if (await FlutterGemma.isModelInstalled(artifactFilename)) {
        await chain.install();
      } else {
        await chain
            .withProgress((progress) => onProgress(progress.toDouble()))
            .install();
      }
    } finally {
      if (onDiagnostic != null) {
        DetailedSmartDownloader.onDiagnostic = previous;
      }
    }
  }

  Future<void> deleteModel() async {
    try {
      await FlutterGemma.uninstallModel(artifactFilename);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting model: $e');
      }
    }
  }
}
