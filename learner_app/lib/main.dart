import 'package:flutter/material.dart';

import 'app.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore();
  await settings.load();
  runApp(IkamvaApp(settings: settings));
}
