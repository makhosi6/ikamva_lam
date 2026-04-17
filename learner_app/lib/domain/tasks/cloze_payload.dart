import 'dart:convert';

/// Typed payload for a cloze (fill-in-the-blank) task (TASKS §3.1).
///
/// Strict validation (duplicates, word counts by level) lives in Phase 3.5.
class ClozePayload {
  ClozePayload({
    required this.sentence,
    required this.answer,
    required this.options,
    this.hintEn,
    this.hintXh,
    this.hintZu,
    this.hintAf,
  }) : assert(
          options.length >= 3 && options.length <= 4,
          'options must have 3–4 entries',
        );

  /// Stem with a single blank marker (e.g. `___` or gap token from generator).
  final String sentence;
  final String answer;

  /// Distractors plus correct answer; length 3–4 inclusive.
  final List<String> options;

  final String? hintEn;
  final String? hintXh;
  final String? hintZu;
  final String? hintAf;

  /// Decodes JSON text; returns `null` if the payload is not a cloze object.
  static ClozePayload? tryParseJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ClozePayload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory ClozePayload.fromJson(Map<String, dynamic> json) {
    final sentence = _reqString(json, 'sentence');
    final answer = _reqString(json, 'answer');
    final options = _reqStringList(json, 'options', minLen: 3, maxLen: 4);
    return ClozePayload(
      sentence: sentence,
      answer: answer,
      options: options,
      hintEn: _optString(json, 'hint_en'),
      hintXh: _optString(json, 'hint_xh'),
      hintZu: _optString(json, 'hint_zu'),
      hintAf: _optString(json, 'hint_af'),
    );
  }

  Map<String, dynamic> toJson() => {
        'sentence': sentence,
        'answer': answer,
        'options': options,
        if (hintEn != null) 'hint_en': hintEn,
        if (hintXh != null) 'hint_xh': hintXh,
        if (hintZu != null) 'hint_zu': hintZu,
        if (hintAf != null) 'hint_af': hintAf,
      };

  String toJsonString() => jsonEncode(toJson());

  static String _reqString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is! String) {
      throw FormatException('ClozePayload.$key must be a non-null string');
    }
    final t = v.trim();
    if (t.isEmpty) {
      throw FormatException('ClozePayload.$key must be non-empty');
    }
    return t;
  }

  static String? _optString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String) {
      throw FormatException('ClozePayload.$key must be a string or null');
    }
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _reqStringList(
    Map<String, dynamic> json,
    String key, {
    required int minLen,
    required int maxLen,
  }) {
    final v = json[key];
    if (v is! List) {
      throw FormatException('ClozePayload.$key must be a JSON array');
    }
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is! String) {
        throw FormatException('ClozePayload.$key[$i] must be a string');
      }
      final t = e.trim();
      if (t.isEmpty) {
        throw FormatException('ClozePayload.$key entries must be non-empty');
      }
      out.add(t);
    }
    if (out.length < minLen || out.length > maxLen) {
      throw FormatException(
        'ClozePayload.$key must have between $minLen and $maxLen items',
      );
    }
    return out;
  }
}
