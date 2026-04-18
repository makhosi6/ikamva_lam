import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

void _noopProgress(String text, int start, int end, String word) {}

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

  void _clearUtteranceHandlers() {
    final engine = _tts;
    if (engine == null) return;
    engine.setProgressHandler(_noopProgress);
    engine.setCompletionHandler(() {});
    engine.setErrorHandler((_) {});
  }

  /// Speaks [text]. Optional [onProgress] receives character offsets into the
  /// spoken string (Android / iOS when the engine reports word ranges).
  Future<void> speak(
    String text, {
    void Function(int start, int end)? onProgress,
    VoidCallback? onComplete,
  }) async {
    final t = text.trim();
    if (t.isEmpty) {
      onComplete?.call();
      return;
    }
    await _ensure();
    final engine = _tts!;
    await engine.stop();

    var trackingDone = false;
    void finishTracking() {
      if (trackingDone) return;
      trackingDone = true;
      _clearUtteranceHandlers();
      onComplete?.call();
    }

    final track = onProgress != null || onComplete != null;
    if (track) {
      engine.setProgressHandler((text, start, end, word) {
        onProgress?.call(start, end);
      });
      engine.setCompletionHandler(finishTracking);
      engine.setErrorHandler((_) => finishTracking());
    } else {
      _clearUtteranceHandlers();
    }

    try {
      await engine.speak(t);
    } on Object {
      if (track) finishTracking();
    }
  }

  Future<void> stop() async {
    if (_tts != null) await _tts!.stop();
  }
}
