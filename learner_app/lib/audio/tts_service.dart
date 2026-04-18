import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'kokoro_wav.dart';

void _noopProgress(String text, int start, int end, String word) {}

/// On-device read-aloud using [Kokoro] (realistic neural TTS) when model assets
/// are present; otherwise falls back to [FlutterTts] (TASKS §12.1).
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  static const _kokoroModelAsset = 'assets/kokoro/kokoro-v1.0.int8.onnx';
  static const _kokoroVoicesAsset = 'assets/kokoro/voices_bundle.json';

  static const _kokoroVoicePreference = [
    'af_bella',
    'af_heart',
    'af_sarah',
    'bf_emma',
    'bm_fable',
  ];

  Kokoro? _kokoro;
  bool _kokoroUsable = false;
  bool _kokoroInitDone = false;
  String? _kokoroVoiceId;

  FlutterTts? _flutterTts;
  bool _flutterReady = false;

  AudioPlayer? _audioPlayer;
  Timer? _wordProgressTimer;

  bool _ready = false;
  bool _stopRequested = false;

  Future<void> _ensure() async {
    if (_ready) return;

    await _initKokoroOnce();
    if (!_kokoroUsable) {
      await _initFlutterTts();
    }
    _ready = true;
  }

  Future<void> _initKokoroOnce() async {
    if (_kokoroInitDone) return;
    if (kIsWeb) {
      _kokoroInitDone = true;
      return;
    }
    _kokoroInitDone = true;

    try {
      final engine = Kokoro(
        const KokoroConfig(
          modelPath: _kokoroModelAsset,
          voicesPath: _kokoroVoicesAsset,
          isInt8: true,
        ),
      );
      await engine.initialize();
      _kokoro = engine;
      _kokoroUsable = true;
    } on Object catch (e, st) {
      debugPrint('TtsService: Kokoro unavailable ($e)');
      debugPrint('$st');
      _kokoro = null;
      _kokoroUsable = false;
    }
  }

  Future<void> _initFlutterTts() async {
    if (_flutterReady) return;
    _flutterTts = FlutterTts();
    final engine = _flutterTts!;

    if (!kIsWeb && Platform.isIOS) {
      try {
        await engine.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      } on Object {
        // best-effort
      }
    }

    var lang = 'en-US';
    try {
      await engine.setLanguage('en-ZA');
      lang = 'en-ZA';
    } on Object {
      await engine.setLanguage('en-US');
      lang = 'en-US';
    }

    await _pickBestEnglishVoice(engine, lang);
    await engine.setSpeechRate(0.42);
    await engine.setVolume(1);
    await engine.setPitch(1);
    _flutterReady = true;
  }

  static Map<String, String> _voiceFields(Map<dynamic, dynamic> raw) {
    String s(Object? k) => '${raw[k] ?? ''}';
    return {
      'name': s('name'),
      'locale': s('locale'),
      'identifier': s('identifier'),
      'quality': s('quality'),
      'features': s('features'),
      'network_required': s('network_required'),
    };
  }

  static int _qualityScore(Map<String, String> v) {
    final q = (v['quality'] ?? '').toLowerCase();
    var score = 1500;
    if (q.contains('premium') || q.contains('very high')) {
      score = 5000;
    } else if (q.contains('enhanced') || q == 'high') {
      score = 4000;
    } else if (q.contains('default') || q.contains('normal')) {
      score = 2000;
    } else if (q.contains('very low') || q.contains('low')) {
      score = 400;
    }

    final features = (v['features'] ?? '').toLowerCase();
    if (features.contains('neural')) {
      score += 400;
    }
    if (v['network_required'] == '1') {
      score += 150;
    }
    return score;
  }

  static int _localeScore(String languageTag, Map<String, String> v) {
    final want = languageTag.toLowerCase().replaceAll('_', '-');
    final loc = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
    if (loc.isEmpty) return 0;
    if (loc == want) return 800;

    final wantParts = want.split('-');
    final locParts = loc.split('-');
    if (wantParts.isEmpty || locParts.isEmpty) return 0;
    if (wantParts.first != locParts.first) return 0;

    if (wantParts.length >= 2 &&
        locParts.length >= 2 &&
        locParts[1] == wantParts[1]) {
      return 700;
    }

    if (locParts.length < 2) return 200;
    final region = locParts[1];
    const order = ['za', 'us', 'gb', 'au', 'ie', 'nz', 'in'];
    final idx = order.indexOf(region);
    if (idx >= 0) {
      return 350 - idx * 12;
    }
    return 180;
  }

  static int _voiceSortKey(String languageTag, Map<String, String> v) {
    return _qualityScore(v) * 10000 + _localeScore(languageTag, v);
  }

  Future<void> _pickBestEnglishVoice(
    FlutterTts engine,
    String languageTag,
  ) async {
    if (kIsWeb) return;
    try {
      final raw = await engine.getVoices;
      if (raw is! List || raw.isEmpty) return;

      Map<String, String>? best;
      var bestKey = -1;

      for (final item in raw) {
        if (item is! Map) continue;
        final v = _voiceFields(Map<dynamic, dynamic>.from(item));
        if ((v['locale'] ?? '').isEmpty || (v['name'] ?? '').isEmpty) {
          continue;
        }

        final loc = v['locale']!.toLowerCase();
        if (!loc.startsWith('en')) continue;

        final key = _voiceSortKey(languageTag, v);
        if (key > bestKey) {
          bestKey = key;
          best = v;
        }
      }

      if (best == null) return;

      final payload = <String, String>{
        'name': best['name']!,
        'locale': best['locale']!,
      };
      final id = best['identifier'];
      if (id != null && id.isNotEmpty) {
        payload['identifier'] = id;
      }
      await engine.setVoice(payload);
    } on Object {
      // default voice
    }
  }

  String _resolveKokoroVoiceId(Kokoro k) {
    if (_kokoroVoiceId != null) return _kokoroVoiceId!;
    for (final id in _kokoroVoicePreference) {
      if (k.availableVoices.containsKey(id)) {
        _kokoroVoiceId = id;
        return id;
      }
    }
    final keys = k.getVoices();
    _kokoroVoiceId = keys.isNotEmpty ? keys.first : 'af_bella';
    return _kokoroVoiceId!;
  }

  /// Splits long lesson strings so phoneme/token limits stay within Kokoro.
  static List<String> _chunkForKokoro(String text, {int maxChars = 260}) {
    final t = text.trim();
    if (t.length <= maxChars) return [t];
    final out = <String>[];
    var start = 0;
    while (start < t.length) {
      var end = (start + maxChars).clamp(0, t.length);
      if (end < t.length) {
        final slice = t.substring(start, end);
        final lastSpace = slice.lastIndexOf(' ');
        if (lastSpace > 40) {
          end = start + lastSpace;
        }
      }
      final piece = t.substring(start, end).trim();
      if (piece.isNotEmpty) out.add(piece);
      start = end;
      while (start < t.length && t[start] == ' ') {
        start++;
      }
    }
    return out.isEmpty ? [t] : out;
  }

  Future<TtsResult> _synthesizeKokoro(Kokoro k, String text) async {
    final voiceId = _resolveKokoroVoiceId(k);
    final chunks = _chunkForKokoro(text);
    if (chunks.length == 1) {
      return k.createTTS(
        text: chunks.single,
        voice: voiceId,
        lang: 'en-us',
        isPhonemes: false,
        speed: 0.95,
      );
    }

    final buffers = <List<num>>[];
    var phonemes = '';
    for (final c in chunks) {
      final r = await k.createTTS(
        text: c,
        voice: voiceId,
        lang: 'en-us',
        isPhonemes: false,
        speed: 0.95,
      );
      buffers.add(r.audio);
      phonemes += r.phonemes;
    }
    final merged = AudioUtils.concatenateAudio(buffers);
    return TtsResult(
      audio: merged,
      sampleRate: sampleRate,
      duration: merged.length / sampleRate,
      phonemes: phonemes,
    );
  }

  void _cancelWordProgressTimer() {
    _wordProgressTimer?.cancel();
    _wordProgressTimer = null;
  }

  void _startApproxWordProgress(
    String text,
    Duration playback,
    void Function(int start, int end)? onProgress,
  ) {
    _cancelWordProgressTimer();
    if (onProgress == null || playback.inMilliseconds < 60) return;

    final matches = RegExp(r'\S+').allMatches(text).toList();
    if (matches.isEmpty) {
      onProgress(0, text.length);
      return;
    }

    final stepMs =
        (playback.inMilliseconds / matches.length).round().clamp(48, 900);
    var i = 0;
    _wordProgressTimer = Timer.periodic(Duration(milliseconds: stepMs), (_) {
      if (_stopRequested || i >= matches.length) {
        _cancelWordProgressTimer();
        return;
      }
      final m = matches[i];
      onProgress(m.start, m.end);
      i++;
    });
  }

  Future<void> _haltPlayback() async {
    _cancelWordProgressTimer();
    try {
      await _audioPlayer?.stop();
    } on Object {
      // ignore
    }
    try {
      await _flutterTts?.stop();
    } on Object {
      // ignore
    }
  }

  Future<void> _speakWithKokoro(
    String text, {
    void Function(int start, int end)? onProgress,
    VoidCallback? onComplete,
  }) async {
    final k = _kokoro!;
    final tts = await _synthesizeKokoro(k, text);
    final pcm = tts.toInt16PCM();
    final wav = pcm16MonoToWavBytes(pcm, tts.sampleRate);

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/ikamva_kokoro_${DateTime.now().microsecondsSinceEpoch}.wav';
    await File(path).writeAsBytes(wav, flush: true);

    _audioPlayer ??= AudioPlayer();
    final player = _audioPlayer!;
    await player.setFilePath(path);
    final duration = player.duration ?? Duration.zero;
    if (duration == Duration.zero && tts.duration > 0) {
      _startApproxWordProgress(
        text,
        Duration(
          milliseconds: (tts.duration * 1000).round().clamp(100, 600000),
        ),
        onProgress,
      );
    } else {
      _startApproxWordProgress(text, duration, onProgress);
    }

    await player.play();
    try {
      await player.playerStateStream.firstWhere(
        (s) => !s.playing || _stopRequested,
      );
    } on Object {
      // playback interrupted
    }

    _cancelWordProgressTimer();
    onProgress?.call(0, text.length);

    try {
      await File(path).delete();
    } on Object {
      // ignore
    }

    onComplete?.call();
  }

  void _clearUtteranceHandlers() {
    final engine = _flutterTts;
    if (engine == null) return;
    engine.setProgressHandler(_noopProgress);
    engine.setCompletionHandler(() {});
    engine.setErrorHandler((_) {});
  }

  /// Speaks [text]. Optional [onProgress] receives character offsets (word-level
  /// with system TTS; approximate word timing with Kokoro).
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
    await _haltPlayback();
    _stopRequested = false;

    final track = onProgress != null || onComplete != null;
    var trackingDone = false;
    void finishTracking() {
      if (trackingDone) return;
      trackingDone = true;
      _clearUtteranceHandlers();
      onComplete?.call();
    }

    if (_kokoroUsable && _kokoro != null) {
      try {
        await _speakWithKokoro(
          t,
          onProgress: onProgress,
          onComplete: track ? finishTracking : null,
        );
        return;
      } on Object catch (e, st) {
        debugPrint('TtsService: Kokoro speak failed, using system TTS ($e)');
        debugPrint('$st');
        _kokoroUsable = false;
        try {
          await _kokoro?.dispose();
        } on Object {
          // ignore
        }
        _kokoro = null;
        await _initFlutterTts();
      }
    }

    final engine = _flutterTts!;
    await engine.stop();

    if (track) {
      engine.setProgressHandler((_, start, end, word) {
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
    _stopRequested = true;
    await _haltPlayback();
  }
}
