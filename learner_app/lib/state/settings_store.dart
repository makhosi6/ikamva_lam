import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences until SQLite profile lands (TASKS Phase 2).
class SettingsStore extends ChangeNotifier {
  bool _onboardingComplete = false;
  bool _ttsEnabled = true;
  String _hintLanguageCode = 'en';
  bool _reduceMotion = false;

  bool get onboardingComplete => _onboardingComplete;
  bool get ttsEnabled => _ttsEnabled;
  String get hintLanguageCode => _hintLanguageCode;
  bool get reduceMotion => _reduceMotion;

  static const _kOnboarding = 'onboarding_complete';
  static const _kTts = 'tts_enabled';
  static const _kHintLang = 'hint_language_code';
  static const _kReduceMotion = 'reduce_motion';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _onboardingComplete = p.getBool(_kOnboarding) ?? false;
    _ttsEnabled = p.getBool(_kTts) ?? true;
    _hintLanguageCode = p.getString(_kHintLang) ?? 'en';
    _reduceMotion = p.getBool(_kReduceMotion) ?? false;
    notifyListeners();
  }

  Future<void> setOnboardingComplete(bool value) async {
    _onboardingComplete = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarding, value);
  }

  Future<void> setTtsEnabled(bool value) async {
    _ttsEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTts, value);
  }

  Future<void> setHintLanguageCode(String code) async {
    _hintLanguageCode = code;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHintLang, code);
  }

  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kReduceMotion, value);
  }
}
