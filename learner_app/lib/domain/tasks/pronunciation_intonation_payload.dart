import 'dart:convert';

/// MCQ for stress, intonation, or minimal-pair style listening (TASKS §3.8).
class PronunciationIntonationPayload {
  PronunciationIntonationPayload({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.referenceLine,
    this.hintEn,
    this.hintXh,
    this.hintZu,
    this.hintAf,
  }) : assert(
          options.length >= 3 && options.length <= 4,
          'options must have 3–4 entries',
        ),
        assert(
          correctIndex >= 0 && correctIndex < options.length,
          'correctIndex in range',
        );

  final String question;
  final List<String> options;
  final int correctIndex;

  /// Optional line played via TTS before answering (may match [question]).
  final String? referenceLine;

  final String? hintEn;
  final String? hintXh;
  final String? hintZu;
  final String? hintAf;

  static PronunciationIntonationPayload? tryParseJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PronunciationIntonationPayload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory PronunciationIntonationPayload.fromJson(Map<String, dynamic> json) {
    final question = _reqString(json, 'question', altKeys: const ['prompt', 'stem']);
    final options = _reqStringList(json, 'options', minLen: 3, maxLen: 4);
    final ci = _reqCorrectIndex(json, options.length);
    return PronunciationIntonationPayload(
      question: question,
      options: options,
      correctIndex: ci,
      referenceLine: _optString(
        json,
        'reference_line',
        altKeys: const ['referenceLine'],
      ),
      hintEn: _optString(json, 'hint_en', altKeys: const ['hintEn']),
      hintXh: _optString(json, 'hint_xh', altKeys: const ['hintXh']),
      hintZu: _optString(json, 'hint_zu', altKeys: const ['hintZu']),
      hintAf: _optString(json, 'hint_af', altKeys: const ['hintAf']),
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        if (referenceLine != null) 'reference_line': referenceLine,
        if (hintEn != null) 'hint_en': hintEn,
        if (hintXh != null) 'hint_xh': hintXh,
        if (hintZu != null) 'hint_zu': hintZu,
        if (hintAf != null) 'hint_af': hintAf,
      };

  static int _reqCorrectIndex(Map<String, dynamic> json, int n) {
    final v = json['correct_index'] ?? json['correctIndex'];
    if (v is int) {
      if (v >= 0 && v < n) return v;
    }
    if (v is double) {
      final r = v.round();
      if ((v - r).abs() < 1e-9 && r >= 0 && r < n) return r;
    }
    if (v is String) {
      final p = int.tryParse(v.trim());
      if (p != null && p >= 0 && p < n) return p;
    }
    throw FormatException('PronunciationIntonationPayload.correct_index invalid');
  }

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
    throw FormatException('PronunciationIntonationPayload missing $key');
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

  static List<String> _reqStringList(
    Map<String, dynamic> json,
    String key, {
    required int minLen,
    required int maxLen,
  }) {
    final v = json[key] ?? json['choices'];
    if (v is! List) {
      throw FormatException('PronunciationIntonationPayload.$key must be a list');
    }
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is! String) {
        throw FormatException('PronunciationIntonationPayload.$key[$i] must be string');
      }
      final t = e.trim();
      if (t.isEmpty) {
        throw FormatException('PronunciationIntonationPayload.$key[$i] empty');
      }
      out.add(t);
    }
    if (out.length < minLen || out.length > maxLen) {
      throw FormatException(
        'PronunciationIntonationPayload.$key length ${out.length} not in $minLen..$maxLen',
      );
    }
    return out;
  }
}
