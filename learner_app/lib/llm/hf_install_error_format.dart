import 'package:flutter_gemma/core/domain/download_error.dart';
import 'package:flutter_gemma/core/domain/download_exception.dart';

/// Technical [DownloadError] description (not [DownloadError.toUserMessage]).
String rawDownloadErrorLabel(DownloadError e) {
  return switch (e) {
    UnauthorizedError() => 'UnauthorizedError()',
    ForbiddenError() => 'ForbiddenError()',
    NotFoundError() => 'NotFoundError()',
    RateLimitedError() => 'RateLimitedError()',
    ServerError(:final statusCode) => 'ServerError(statusCode: $statusCode)',
    NetworkError(:final message) => 'NetworkError(message: $message)',
    CanceledError() => 'CanceledError()',
    UnknownError(:final message) => 'UnknownError(message: $message)',
  };
}

/// As-reported install/download failure for UI (no friendly rewriting).
String rawInstallErrorLabel(Object error) {
  if (error is DownloadException) {
    return 'DownloadException(${rawDownloadErrorLabel(error.error)})';
  }
  return error.toString();
}
