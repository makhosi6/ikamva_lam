import 'dart:convert';

/// Typed payload for **read aloud** tasks (spec §4.1.2, TASKS §3.7).
class ReadAloudPayload {
  ReadAloudPayload({
    required this.displayText,
    this.instructionEn,
    this.ttsLocale,
    this.hintEn,
    this.hintXh,
    this.hintZu,
    this.hintAf,
  });

  /// Line(s) the learner reads on screen (keep short; validators enforce length).
  final String displayText;

  /// Short framing, e.g. “Read this like a friendly question.”
  final String? instructionEn;

  /// BCP-47 tag for reference TTS, e.g. `en-ZA`.
  final String? ttsLocale;

  final String? hintEn;
  final String? hintXh;
  final String? hintZu;
  final String? hintAf;

  static ReadAloudPayload? tryParseJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ReadAloudPayload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory ReadAloudPayload.fromJson(Map<String, dynamic> json) {
    return ReadAloudPayload(
      displayText: _reqString(json, 'display_text', altKeys: const ['displayText']),
      instructionEn: _optString(json, 'instruction_en', altKeys: const ['instructionEn']),
      ttsLocale: _optString(json, 'tts_locale', altKeys: const ['ttsLocale']),
      hintEn: _optString(json, 'hint_en', altKeys: const ['hintEn']),
      hintXh: _optString(json, 'hint_xh', altKeys: const ['hintXh']),
      hintZu: _optString(json, 'hint_zu', altKeys: const ['hintZu']),
      hintAf: _optString(json, 'hint_af', altKeys: const ['hintAf']),
    );
  }

  Map<String, dynamic> toJson() => {
        'display_text': displayText,
        if (instructionEn != null) 'instruction_en': instructionEn,
        if (ttsLocale != null) 'tts_locale': ttsLocale,
        if (hintEn != null) 'hint_en': hintEn,
        if (hintXh != null) 'hint_xh': hintXh,
        if (hintZu != null) 'hint_zu': hintZu,
        if (hintAf != null) 'hint_af': hintAf,
      };

  static String _reqString(
    Map<String, dynamic> json,
    String key, {
    List<String> altKeys = const [],
  }) {
    for (final k in [key, ...altKeys]) {
      final v = json[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
    }
    throw FormatException('ReadAloudPayload missing non-empty string for $key');
  }

  static String? _optString(
    Map<String, dynamic> json,
    String key, {
    List<String> altKeys = const [],
  }) {
    for (final k in [key, ...altKeys]) {
      final v = json[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }
}
