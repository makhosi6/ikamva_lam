import 'package:shared_preferences/shared_preferences.dart';

/// Tracks that the one-time model prepare flow completed (HTTP install + verify).
abstract final class ModelPreparePrefs {
  static const _doneKey = 'ikamva_model_install_done_v1';

  static Future<bool> isPrepareDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_doneKey) ?? false;
  }

  static Future<void> setPrepareDone(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_doneKey, value);
  }

  /// Dev / QA: show the model prepare flow again on next cold start.
  static Future<void> clearPrepareDone() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_doneKey);
  }
}
