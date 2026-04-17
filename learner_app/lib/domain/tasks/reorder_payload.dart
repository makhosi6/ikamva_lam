import 'dart:convert';

/// Typed payload for a sentence-reorder task (TASKS §3.2).
///
/// [tokens] is the bank of phrases (short words or segments). [correctOrder]
/// lists, for each reading position left-to-right, which token index from the
/// bank appears there. It must be a permutation of `0 .. tokens.length - 1`.
///
/// Example: tokens `["like", "I", "apples"]`, correctOrder `[1,0,2]` reads
/// "I like apples". Stricter checks (duplicate strings, length caps) belong in
/// Phase 3.5.
class ReorderPayload {
  ReorderPayload({
    required this.tokens,
    required this.correctOrder,
  }) {
    if (tokens.length < 2) {
      throw FormatException('ReorderPayload.tokens must have at least 2 items');
    }
    _assertPermutation(correctOrder, tokens.length);
  }

  final List<String> tokens;

  /// For each sentence position (0 = leftmost), the index into [tokens].
  final List<int> correctOrder;

  static void _assertPermutation(List<int> order, int n) {
    if (order.length != n) {
      throw FormatException(
        'ReorderPayload.correctOrder length must equal tokens length ($n)',
      );
    }
    final seen = <int>{};
    for (final i in order) {
      if (i < 0 || i >= n) {
        throw FormatException(
          'ReorderPayload.correctOrder contains out-of-range index $i',
        );
      }
      if (!seen.add(i)) {
        throw FormatException(
          'ReorderPayload.correctOrder must be a permutation (duplicate $i)',
        );
      }
    }
  }

  static ReorderPayload? tryParseJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ReorderPayload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory ReorderPayload.fromJson(Map<String, dynamic> json) {
    final tokens = _reqStringList(json, 'tokens', minLen: 2);
    final order = _reqIntList(json, 'correct_order');
    return ReorderPayload(tokens: tokens, correctOrder: order);
  }

  Map<String, dynamic> toJson() => {
        'tokens': tokens,
        'correct_order': correctOrder,
      };

  String toJsonString() => jsonEncode(toJson());

  /// Sentence built from [tokens] using [correctOrder] (for display / TTS).
  String sentenceText({String separator = ' '}) =>
      correctOrder.map((i) => tokens[i]).join(separator);

  static List<String> _reqStringList(
    Map<String, dynamic> json,
    String key, {
    required int minLen,
  }) {
    final v = json[key];
    if (v is! List) {
      throw FormatException('ReorderPayload.$key must be a JSON array');
    }
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is! String) {
        throw FormatException('ReorderPayload.$key[$i] must be a string');
      }
      final t = e.trim();
      if (t.isEmpty) {
        throw FormatException('ReorderPayload.$key entries must be non-empty');
      }
      out.add(t);
    }
    if (out.length < minLen) {
      throw FormatException(
        'ReorderPayload.$key must have at least $minLen items',
      );
    }
    return out;
  }

  static List<int> _reqIntList(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is! List) {
      throw FormatException('ReorderPayload.$key must be a JSON array');
    }
    final out = <int>[];
    for (var i = 0; i < v.length; i++) {
      out.add(_jsonInt(v[i], '$key[$i]'));
    }
    return out;
  }

  static int _jsonInt(Object? e, String path) {
    if (e == null) {
      throw FormatException('ReorderPayload.$path must be non-null');
    }
    if (e is int) return e;
    if (e is double) {
      final r = e.round();
      if ((e - r).abs() > 1e-9) {
        throw FormatException('ReorderPayload.$path must be a whole number');
      }
      return r;
    }
    throw FormatException('ReorderPayload.$path must be a number');
  }
}
