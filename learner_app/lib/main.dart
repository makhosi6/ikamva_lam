import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/di/service_registry.dart';
import 'package:flutter_gemma/core/domain/web_storage_mode.dart';

import 'app.dart';
import 'db/app_database.dart';
import 'db/database_connection.dart';
import 'db/seed.dart';
import 'llm/android_hf_download_setup.dart';
import 'llm/huggingface_auth_token_store.dart';
import 'llm/ikamva_background_download_service.dart';
import 'llm/llm_service.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureAndroidLargeModelHfDownloadSupport();
  final hfToken = await HuggingfaceAuthTokenStore.resolveEffectiveToken();
  await HuggingfaceAuthTokenStore.assertReleaseHasToken(hfToken);
  try {
    await ServiceRegistry.initialize(
      huggingFaceToken: hfToken,
      maxDownloadRetries: 10,
      webStorageMode: WebStorageMode.cacheApi,
      downloadService:
          kIsWeb ? null : IkamvaBackgroundDownloadService(),
    );
  } on Object catch (e, st) {
    // Avoid crashing the whole app if the plugin fails early; Gemma screens
    // and [FlutterGemmaLlmEngine] surface errors when used.
    debugPrint('ServiceRegistry.initialize failed: $e\n$st');
  }
  final settings = SettingsStore();
  await settings.load();
  LlmService.instance.configure(settings);
  final database = IkamvaDatabase(openIkamvaDatabaseFile());
  await ensureDevSeed(database);
  await ensureExtraSeedTaskTypes(database);
  await ensureMultiTopicQuestSeed(database);
  runApp(IkamvaApp(settings: settings, database: database));
}
