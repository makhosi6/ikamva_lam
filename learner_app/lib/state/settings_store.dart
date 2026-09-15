import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../llm/model_prepare_prefs.dart';
import '../llm/on_device_gemma_variant.dart';

/// Local preferences until SQLite profile lands (TASKS Phase 2).
class SettingsStore extends ChangeNotifier {
  bool _onboardingComplete = false;
  bool _ttsEnabled = true;
  String _hintLanguageCode = 'en';
  bool _reduceMotion = false;
  bool _lowRamProfile = false;
  bool _voiceCommandsEnabled = false;
  bool _normaliseMixedLanguageAnswers = true;
  OnDeviceGemmaVariant _onDeviceGemmaVariant =
      OnDeviceGemmaVariant.gemma3nE2b;
  bool _gemma4SetupComplete = false;

  bool get onboardingComplete => _onboardingComplete;
  bool get ttsEnabled => _ttsEnabled;
  String get hintLanguageCode => _hintLanguageCode;
  bool get reduceMotion => _reduceMotion;
  bool get lowRamProfile => _lowRamProfile;
  bool get voiceCommandsEnabled => _voiceCommandsEnabled;
  bool get normaliseMixedLanguageAnswers => _normaliseMixedLanguageAnswers;
  OnDeviceGemmaVariant get onDeviceGemmaVariant => _onDeviceGemmaVariant;

  /// Legacy name — prefer [onDeviceGemmaVariant].
  OnDeviceGemmaVariant get gemma4OnDeviceVariant => _onDeviceGemmaVariant;
  bool get gemma4SetupComplete => _gemma4SetupComplete;

  static const _kOnboarding = 'onboarding_complete';
  static const _kTts = 'tts_enabled';
  static const _kHintLang = 'hint_language_code';
  static const _kReduceMotion = 'reduce_motion';
  static const _kLowRam = 'low_ram_profile';
  static const _kVoiceCommands = 'voice_commands_enabled';
  static const _kNormaliseAnswers = 'normalise_mixed_language_answers';
  static const _kGemma4Variant = 'gemma4_ondevice_variant';
  static const _kGemma4SetupComplete = 'gemma4_setup_complete_v1';

  /// Legacy [ModelPreparePrefs] fingerprint when E2B shipped inside the APK/IPA.
  static const _legacyBundledE2bFingerprint =
      'bundle:assets/models/gemma-4-E2B-it.litertlm';

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

    final rawVariant = p.getString(_kGemma4Variant);
    final storedVariant = onDeviceGemmaVariantFromName(rawVariant);
    if (storedVariant != null) {
      _onDeviceGemmaVariant = storedVariant;
      // Normalize legacy keys (`e2bHuggingFace` → `gemma4E2b`, etc.).
      if (rawVariant != storedVariant.name) {
        await p.setString(_kGemma4Variant, storedVariant.name);
      }
    }
    _gemma4SetupComplete = p.getBool(_kGemma4SetupComplete) ?? false;

    if (!_gemma4SetupComplete) {
      await _migrateGemma4SetupFromLegacyPreparePrefs(p);
    }

    notifyListeners();
  }

  /// Legacy installs prepared from a bundled E2B asset: map to Gemma 4 E2B HF.
  Future<void> _migrateGemma4SetupFromLegacyPreparePrefs(
    SharedPreferences p,
  ) async {
    final done = await ModelPreparePrefs.isPrepareDone();
    if (!done) return;
    final fp = await ModelPreparePrefs.preparedInstallFingerprint();
    if (fp == _legacyBundledE2bFingerprint) {
      _onDeviceGemmaVariant = OnDeviceGemmaVariant.gemma4E2b;
      _gemma4SetupComplete = true;
      await p.setString(_kGemma4Variant, _onDeviceGemmaVariant.name);
      await p.setBool(_kGemma4SetupComplete, true);
    }
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

  Future<void> setOnDeviceGemmaVariant(OnDeviceGemmaVariant value) async {
    _onDeviceGemmaVariant = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGemma4Variant, value.name);
  }

  /// Legacy name — prefer [setOnDeviceGemmaVariant].
  Future<void> setGemma4OnDeviceVariant(OnDeviceGemmaVariant value) =>
      setOnDeviceGemmaVariant(value);

  Future<void> setGemma4SetupComplete(bool value) async {
    _gemma4SetupComplete = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kGemma4SetupComplete, value);
  }
}
