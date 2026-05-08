import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'app.dart';
import 'db/app_database.dart';
import 'db/database_connection.dart';
import 'db/seed.dart';
import 'llm/gemma_asset_selection_repair.dart';
import 'llm/llm_service.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterGemma.initialize(
      maxDownloadRetries: 10,
    );
  } on Object catch (e, st) {
    // Avoid crashing the whole app if the plugin fails early; Gemma screens
    // and [FlutterGemmaLlmEngine] surface errors when used.
    debugPrint('FlutterGemma.initialize failed: $e\n$st');
  }
  final settings = SettingsStore();
  await settings.load();
  await repairGemma4SelectionIfBundledAssetMissing(settings);
  LlmService.instance.configure(settings);
  final database = IkamvaDatabase(openIkamvaDatabaseFile());
  await ensureDevSeed(database);
  await ensureExtraSeedTaskTypes(database);
  await ensureMultiTopicQuestSeed(database);
  runApp(IkamvaApp(settings: settings, database: database));
}
