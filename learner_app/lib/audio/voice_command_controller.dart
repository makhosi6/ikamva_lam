import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Handlers for hands-free commands (spec §2.1, TASKS §12.3).
class VoiceCommandHandlers {
  const VoiceCommandHandlers({
    required this.onRepeat,
    required this.onSkip,
    required this.onReadAloud,
    required this.onTranscript,
  });

  final VoidCallback onRepeat;
  final Future<void> Function() onSkip;
  final VoidCallback onReadAloud;
  final void Function(String transcript) onTranscript;
}

/// Push-to-talk: tap mic, speak once, commands are parsed from final text.
class VoiceCommandController {
  VoiceCommandController(this.handlers);

  final VoiceCommandHandlers handlers;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ValueNotifier<bool> listening = ValueNotifier(false);

  bool _initialized = false;

  Future<bool> ensureInitialized() async {
    if (_initialized) return _speech.isAvailable;
    _initialized = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    return _initialized && _speech.isAvailable;
  }

  /// Call from [State.dispose]; releases the mic listener notifier.
  void shutdown() {
    unawaited(_speech.cancel());
    listening.dispose();
  }

  Future<void> toggleListen() async {
    if (listening.value) {
      await _speech.stop();
      listening.value = false;
      return;
    }
    final ok = await ensureInitialized();
    if (!ok) return;

    listening.value = true;
    try {
      await _speech.listen(
        onResult: (r) {
          if (!r.finalResult) return;
          final text = r.recognizedWords.trim();
          listening.value = false;
          unawaited(_speech.stop());
          if (text.isEmpty) return;
          _dispatch(text);
        },
        listenFor: const Duration(seconds: 14),
        pauseFor: const Duration(seconds: 2),
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } on Object {
      listening.value = false;
    }
  }

  void _dispatch(String words) {
    final w = words.toLowerCase();
    if (RegExp(r'\b(repeat|again|replay)\b').hasMatch(w)) {
      handlers.onRepeat();
      return;
    }
    if (RegExp(r'\b(skip|next)\b').hasMatch(w)) {
      unawaited(handlers.onSkip());
      return;
    }
    if (RegExp(r'\b(read aloud|read it|listen|hear it|play)\b').hasMatch(w)) {
      handlers.onReadAloud();
      return;
    }
    handlers.onTranscript(words);
  }
}
