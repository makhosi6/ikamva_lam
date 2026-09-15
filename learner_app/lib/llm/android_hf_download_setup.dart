import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

/// Same group string as `flutter_gemma` [`SmartDownloader`] (`smart_downloads`).
const String kFlutterGemmaHfDownloadTaskGroup = 'smart_downloads';

/// Android `background_downloader` kills long transfers after ~9 minutes unless
/// the task runs as a **foreground** download. Foreground mode only activates
/// when a **running** notification is configured for the task group; otherwise
/// `TaskRunner` keeps `runInForeground == false` and you get `Task timed out`
/// mid-file (often around high progress % on slow links / OEM throttling).
///
/// Call once after [WidgetsFlutterBinding.ensureInitialized], before any HF
/// model install. Safe no-op on non-Android and on web.
///
/// This only registers notification/foreground behavior for
/// [background_downloader]; it does not fetch weights. Actual installs skip
/// network work when the target file is already present
/// ([GemmaHfModelDownloadService.downloadModel]).
Future<void> configureAndroidLargeModelHfDownloadSupport() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final fd = FileDownloader();
    fd.configureNotificationForGroup(
      kFlutterGemmaHfDownloadTaskGroup,
      running: const TaskNotification(
        'Downloading Gemma 4 model',
        '{filename} · {progress} · {timeRemaining}',
      ),
      complete: const TaskNotification(
        'Model ready',
        '{filename} finished downloading.',
      ),
      error: const TaskNotification(
        'Download failed',
        'Could not finish {filename}. Open the app and try again.',
      ),
      progressBar: true,
    );
    await fd.configure(
      androidConfig: [(Config.runInForeground, Config.always)],
    );
  } on Object catch (e, st) {
    debugPrint('configureAndroidLargeModelHfDownloadSupport: $e\n$st');
  }
}

/// Android 13+ needs notification permission for the foreground download
/// notification; without it, OEMs may not promote the worker and the 9-minute
/// watchdog can still fire.
Future<void> ensureAndroidModelDownloadNotificationPermission() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final fd = FileDownloader();
    const pt = PermissionType.notifications;
    final status = await fd.permissions.status(pt);
    if (status == PermissionStatus.granted) return;
    await fd.permissions.request(pt);
  } on Object catch (e, st) {
    debugPrint('ensureAndroidModelDownloadNotificationPermission: $e\n$st');
  }
}
