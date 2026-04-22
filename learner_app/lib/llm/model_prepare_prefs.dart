import 'package:shared_preferences/shared_preferences.dart';

import 'model_prepare_config.dart';

/// Tracks that the one-time model prepare flow completed (HTTP install + verify).
abstract final class ModelPreparePrefs {
  static const _doneKey = 'ikamva_model_install_done_v1';
  static const _modelUrlKey = 'ikamva_model_install_url_v1';
  static const _preparedAtEpochMsKey = 'ikamva_model_prepared_at_epoch_ms_v1';

  static Future<bool> isPrepareDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_doneKey) ?? false;
  }

  static Future<void> setPrepareDone(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_doneKey, value);
    if (!value) {
      await p.remove(_modelUrlKey);
      await p.remove(_preparedAtEpochMsKey);
      return;
    }
    await p.setString(_modelUrlKey, ModelPrepareConfig.networkUrl);
    await p.setInt(
      _preparedAtEpochMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Dev / QA: show the model prepare flow again on next cold start.
  static Future<void> clearPrepareDone() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_doneKey);
    await p.remove(_modelUrlKey);
    await p.remove(_preparedAtEpochMsKey);
  }

  static Future<String?> preparedModelUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_modelUrlKey);
  }

  static Future<DateTime?> preparedAt() async {
    final p = await SharedPreferences.getInstance();
    final epochMs = p.getInt(_preparedAtEpochMsKey);
    if (epochMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  static Future<void> markPrepareDoneForCurrentConfig() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_doneKey, true);
    await p.setString(_modelUrlKey, ModelPrepareConfig.networkUrl);
    await p.setInt(
      _preparedAtEpochMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// True when app should go through model prepare/re-verify:
  /// - never prepared
  /// - prepared flag false
  /// - URL changed since last successful prepare
  static Future<bool> shouldPrepareForCurrentConfig() async {
    final p = await SharedPreferences.getInstance();
    final done = p.getBool(_doneKey) ?? false;
    if (!done) return true;
    final lastUrl = p.getString(_modelUrlKey) ?? '';
    return lastUrl != ModelPrepareConfig.networkUrl;
  }
}
