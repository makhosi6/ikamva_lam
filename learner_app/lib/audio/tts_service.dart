import 'package:flutter_tts/flutter_tts.dart';

/// Reads task text aloud when enabled in settings (TASKS §12.1).
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  FlutterTts? _tts;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage('en-ZA');
    } on Object {
      await _tts!.setLanguage('en-US');
    }
    await _tts!.setSpeechRate(0.42);
    await _tts!.setVolume(1);
    await _tts!.setPitch(1);
    _ready = true;
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensure();
    await _tts!.stop();
    await _tts!.speak(t);
  }

  Future<void> stop() async {
    if (_tts != null) await _tts!.stop();
  }
}
