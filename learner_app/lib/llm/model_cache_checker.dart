import 'gemma_hf_model_download_service.dart';
import 'model_prepare_config.dart';
import 'model_prepare_prefs.dart';
import 'on_device_gemma_variant.dart';

/// Stateless helper that answers "is the model for this variant already on
/// disk and still matching the current install fingerprint?"
///
/// Used by [FlutterGemmaLlmEngine] to skip a redundant Hugging Face download
/// when the weights file is already present and the prepare prefs fingerprint
/// matches.
abstract final class ModelCacheChecker {
  /// Returns `true` only when:
  /// 1. The plugin/model file for [variant] exists on disk, **and**
  /// 2. [ModelPreparePrefs.shouldPrepareForFingerprint] returns `false` for
  ///    the fingerprint of [variant] — meaning the stored fingerprint matches
  ///    (prepare already done for this exact artifact).
  ///
  /// No network calls — file-system + SharedPreferences only.
  static Future<bool> isCached(OnDeviceGemmaVariant variant) async {
    final service = GemmaHfModelDownloadService.forVariant(variant);
    final isInstalled = await service.isPluginModelInstalled();
    if (!isInstalled) return false;

    final fingerprint = ModelPrepareConfig.installFingerprint(variant);
    final shouldPrepare =
        await ModelPreparePrefs.shouldPrepareForFingerprint(fingerprint);
    return !shouldPrepare;
  }
}
