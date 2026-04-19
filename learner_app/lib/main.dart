import 'package:flutter/material.dart';

import 'app.dart';
import 'db/app_database.dart';
import 'db/database_connection.dart';
import 'db/seed.dart';
import 'llm/llm_service.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore();
  await settings.load();
  await LlmService.instance.configure(settings);
  final database = IkamvaDatabase(openIkamvaDatabaseFile());
  await ensureDevSeed(database);
  await ensureExtraSeedTaskTypes(database);
  await ensureMultiTopicQuestSeed(database);
  runApp(IkamvaApp(settings: settings, database: database));
}
