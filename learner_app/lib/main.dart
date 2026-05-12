import 'package:flutter/material.dart';

import 'app.dart';
import 'db/app_database.dart';
import 'db/database_connection.dart';
import 'db/seed.dart';
import 'llm/android_hf_download_setup.dart';
import 'llm/huggingface_auth_token_store.dart';
import 'llm/llm_service.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureAndroidLargeModelHfDownloadSupport();
  final hfToken = await HuggingfaceAuthTokenStore.resolveEffectiveToken();
  await HuggingfaceAuthTokenStore.assertReleaseHasToken(hfToken);

  final settings = SettingsStore();
  await settings.load();
  LlmService.instance.configure(settings);
  final database = IkamvaDatabase(openIkamvaDatabaseFile());
  await ensureDevSeed(database);
  await ensureExtraSeedTaskTypes(database);
  await ensureMultiTopicQuestSeed(database);

  // `--dart-define` values are only readable via `String/int/bool.fromEnvironment`.
  // `Platform.environment` is the OS process env (effectively empty on Android/iOS)
  // and will NOT show dart-defines. Edit launch.json / .env then HOT RESTART.
  const forceCpuStr = String.fromEnvironment('IKAMVA_FORCE_CPU_BACKEND');
  const forceCpuInt = int.fromEnvironment('IKAMVA_FORCE_CPU_BACKEND');
  const hfTokenDefine = String.fromEnvironment('IKAMVA_HF_TOKEN');
  const hfTokenAlt1 = String.fromEnvironment('HUGGINGFACE_TOKEN');
  const hfTokenAlt2 = String.fromEnvironment('HF_TOKEN');
  const modelUrl = String.fromEnvironment('IKAMVA_MODEL_DOWNLOAD_URL');
  String redact(String? v) {
    if (v == null || v.isEmpty) return '<empty>';
    return '${v.substring(0, v.length.clamp(0, 6))}…';
  }
  debugPrint('''
[ikamva env]
  resolved HF token (from store):  ${redact(hfToken)}
  IKAMVA_FORCE_CPU_BACKEND (str):  "$forceCpuStr"
  IKAMVA_FORCE_CPU_BACKEND (int):  $forceCpuInt
  IKAMVA_HF_TOKEN (define):        ${redact(hfTokenDefine)}
  HUGGINGFACE_TOKEN (define):      ${redact(hfTokenAlt1)}
  HF_TOKEN (define):               ${redact(hfTokenAlt2)}
  IKAMVA_MODEL_DOWNLOAD_URL:       ${modelUrl.isEmpty ? '<empty>' : modelUrl}
''');
  runApp(IkamvaApp(settings: settings, database: database));
}


