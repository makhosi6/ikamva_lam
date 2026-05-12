import 'dart:async';
import 'package:flutter/foundation.dart';

/// Download error types (forked from flutter_gemma for dependency-free transfers).
sealed class DownloadError {
  const DownloadError();

  const factory DownloadError.unauthorized() = UnauthorizedError;
  const factory DownloadError.forbidden() = ForbiddenError;
  const factory DownloadError.notFound() = NotFoundError;
  const factory DownloadError.rateLimited() = RateLimitedError;
  const factory DownloadError.serverError(int statusCode) = ServerError;
  const factory DownloadError.network(String message) = NetworkError;
  const factory DownloadError.canceled() = CanceledError;
  const factory DownloadError.unknown(String message) = UnknownError;
}

final class UnauthorizedError extends DownloadError {
  const UnauthorizedError();
}

final class ForbiddenError extends DownloadError {
  const ForbiddenError();
}

final class NotFoundError extends DownloadError {
  const NotFoundError();
}

final class RateLimitedError extends DownloadError {
  const RateLimitedError();
}

final class ServerError extends DownloadError {
  const ServerError(this.statusCode);
  final int statusCode;
}

final class NetworkError extends DownloadError {
  const NetworkError(this.message);
  final String message;
}

final class CanceledError extends DownloadError {
  const CanceledError();
}

final class UnknownError extends DownloadError {
  const UnknownError(this.message);
  final String message;
}

/// Custom exception for download failures.
class DownloadException implements Exception {
  const DownloadException(this.error);

  final DownloadError error;

  @override
  String toString() => 'DownloadException: ${error.toUserMessage()}';
}

extension DownloadErrorMessage on DownloadError {
  String toUserMessage() {
    return switch (this) {
      UnauthorizedError() => 'Authentication required (HTTP 401).\n'
          'Please provide a valid Hugging Face token in Settings.',
      ForbiddenError() => 'Access forbidden (HTTP 403).\n'
          'Your Hugging Face token may be invalid or lack access to this model.',
      NotFoundError() => 'Model not found (HTTP 404).\n'
          'Please check the URL and ensure the model exists.',
      RateLimitedError() => 'Rate limit exceeded (HTTP 429).\n'
          'Please wait a few minutes before trying again.',
      ServerError(:final statusCode) => 'Server error (HTTP $statusCode).\n'
          'Please try again later.',
      NetworkError(:final message) => 'Network error: $message\n'
          'Please check your internet connection.',
      CanceledError() => 'Download was canceled.',
      UnknownError(:final message) => 'Download failed: $message',
    };
  }
}

/// Token for cancelling model downloads.
class CancelToken {
  Completer<void>? _completer;
  String? _cancelReason;
  StackTrace? _stackTrace;

  bool get isCancelled => _cancelReason != null;
  String? get cancelReason => _cancelReason;

  Future<void> get whenCancelled {
    _completer ??= Completer<void>();
    if (isCancelled) {
      return Future.value();
    }
    return _completer!.future;
  }

  void cancel([String reason = 'Operation cancelled']) {
    if (isCancelled) {
      debugPrint(
        'CancelToken already cancelled. Previous: $_cancelReason, new: $reason',
      );
      return;
    }
    _cancelReason = reason;
    _stackTrace = StackTrace.current;
    _completer?.complete();
    debugPrint('CancelToken cancelled: $reason');
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw DownloadCancelledException(_cancelReason!, _stackTrace);
    }
  }

  static bool isCancel(Object error) => error is DownloadCancelledException;
}

class DownloadCancelledException implements Exception {
  DownloadCancelledException(this.message, this.stackTrace);
  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => 'DownloadCancelledException: $message';
}
