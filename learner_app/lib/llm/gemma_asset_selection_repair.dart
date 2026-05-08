import '../state/settings_store.dart';
import 'flutter_gemma_llm_engine.dart';
import 'gemma4_ondevice_variant.dart';
import 'llm_service.dart';
import 'model_asset_manifest.dart';
import 'model_prepare_config.dart';
import 'model_prepare_prefs.dart';

/// If the user chose bundled E2B but this build’s asset manifest does not list
/// the `.litertlm`, reset the Gemma gate so they pick **E4B** (or restore
/// [pubspec.yaml] and rebuild).
Future<void> repairGemma4SelectionIfBundledAssetMissing(SettingsStore s) async {
  if (!shouldUseFlutterGemmaEngine) return;
  if (!s.gemma4SetupComplete) return;
  if (s.gemma4OnDeviceVariant != Gemma4OnDeviceVariant.e2bBundled) return;
  final path = ModelPrepareConfig.bundledModelAssetPath;
  if (await modelAssetListedInBundle(path)) return;

  await s.setGemma4OnDeviceVariant(Gemma4OnDeviceVariant.e4bNetwork);
  await s.setGemma4SetupComplete(false);
  await ModelPreparePrefs.clearPrepareDone();
  LlmService.instance.invalidateCachedEngine();
}
