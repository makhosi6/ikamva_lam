import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences until SQLite profile lands (TASKS Phase 2).
class SettingsStore extends ChangeNotifier {
  bool _onboardingComplete = false;
  bool _ttsEnabled = true;
  String _hintLanguageCode = 'en';
  bool _reduceMotion = false;
  bool _lowRamProfile = false;
  bool _voiceCommandsEnabled = false;
  bool _normaliseMixedLanguageAnswers = true;

  bool get onboardingComplete => _onboardingComplete;
  bool get ttsEnabled => _ttsEnabled;
  String get hintLanguageCode => _hintLanguageCode;
  bool get reduceMotion => _reduceMotion;
  bool get lowRamProfile => _lowRamProfile;
  bool get voiceCommandsEnabled => _voiceCommandsEnabled;
  bool get normaliseMixedLanguageAnswers => _normaliseMixedLanguageAnswers;

  static const _kOnboarding = 'onboarding_complete';
  static const _kTts = 'tts_enabled';
  static const _kHintLang = 'hint_language_code';
  static const _kReduceMotion = 'reduce_motion';
  static const _kLowRam = 'low_ram_profile';
  static const _kVoiceCommands = 'voice_commands_enabled';
  static const _kNormaliseAnswers = 'normalise_mixed_language_answers';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _onboardingComplete = p.getBool(_kOnboarding) ?? false;
    _ttsEnabled = p.getBool(_kTts) ?? true;
    _hintLanguageCode = p.getString(_kHintLang) ?? 'en';
    _reduceMotion = p.getBool(_kReduceMotion) ?? false;
    _lowRamProfile = p.getBool(_kLowRam) ?? false;
    _voiceCommandsEnabled = p.getBool(_kVoiceCommands) ?? false;
    _normaliseMixedLanguageAnswers =
        p.getBool(_kNormaliseAnswers) ?? true;
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

  Future<void> setLowRamProfile(bool value) async {
    _lowRamProfile = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLowRam, value);
  }

  Future<void> setVoiceCommandsEnabled(bool value) async {
    _voiceCommandsEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVoiceCommands, value);
  }

  Future<void> setNormaliseMixedLanguageAnswers(bool value) async {
    _normaliseMixedLanguageAnswers = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNormaliseAnswers, value);
  }
}
