import 'package:flutter_gemma/core/model_management/cancel_token.dart';
import 'package:flutter_gemma/core/services/download_service.dart';

import 'detailed_smart_downloader.dart';

/// Same contract as [BackgroundDownloaderService] but uses [DetailedSmartDownloader]
/// so [TaskStatus.failed] / resume errors surface native exception text in
/// [DownloadError.network] messages for the UI.
class IkamvaBackgroundDownloadService implements DownloadService {
  @override
  Future<void> download(
    String url,
    String targetPath, {
    String? token,
    CancelToken? cancelToken,
  }) {
    return DetailedSmartDownloader.download(
      url: url,
      targetPath: targetPath,
      token: token,
      cancelToken: cancelToken,
    );
  }

  @override
  Stream<int> downloadWithProgress(
    String url,
    String targetPath, {
    String? token,
    int maxRetries = 10,
    CancelToken? cancelToken,
    bool? foreground,
  }) {
    return DetailedSmartDownloader.downloadWithProgress(
      url: url,
      targetPath: targetPath,
      token: token,
      maxRetries: maxRetries,
      cancelToken: cancelToken,
      foreground: foreground,
    );
  }
}
