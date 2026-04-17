import 'dart:convert';

/// One correct association between a left-column item and a right-column item.
class MatchPair {
  const MatchPair({required this.leftIndex, required this.rightIndex});

  final int leftIndex;
  final int rightIndex;

  List<int> toJsonList() => [leftIndex, rightIndex];
}

/// Typed payload for a two-column matching task (TASKS §3.3).
///
/// [left] and [right] are parallel banks of labels (same length). [pairs]
/// lists each correct `(leftIndex → rightIndex)`; together they must form a
/// single bijection between column indices `0 … n-1`.
///
/// JSON `pairs` may be:
/// - a JSON array of `[left, right]` integer pairs, or
/// - a JSON array of objects `{"left": L, "right": R}`, or
/// - a JSON object map from left index (string key) to right index (value).
///
/// Stricter checks (duplicate labels, curriculum caps) belong in Phase 3.5.
class MatchPayload {
  MatchPayload({
    required this.left,
    required this.right,
    required this.pairs,
  }) {
    if (left.isEmpty) {
      throw FormatException('MatchPayload.left must not be empty');
    }
    if (left.length != right.length) {
      throw FormatException(
        'MatchPayload.left and right must have the same length',
      );
    }
    _assertBijection(pairs, left.length);
  }

  final List<String> left;
  final List<String> right;
  final List<MatchPair> pairs;

  static MatchPayload? tryParseJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return MatchPayload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory MatchPayload.fromJson(Map<String, dynamic> json) {
    final left = _reqStringList(json, 'left', minLen: 1);
    final right = _reqStringList(json, 'right', minLen: 1);
    final pairsRaw = json['pairs'];
    if (pairsRaw == null) {
      throw FormatException('MatchPayload.pairs is required');
    }
    final pairs = _parsePairs(pairsRaw, left.length);
    return MatchPayload(left: left, right: right, pairs: pairs);
  }

  Map<String, dynamic> toJson() => {
        'left': left,
        'right': right,
        'pairs': pairs.map((p) => p.toJsonList()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  static void _assertBijection(List<MatchPair> pairs, int n) {
    if (pairs.length != n) {
      throw FormatException(
        'MatchPayload.pairs must have exactly $n entries (one per row)',
      );
    }
    final leftSeen = <int>{};
    final rightSeen = <int>{};
    for (final p in pairs) {
      if (p.leftIndex < 0 || p.leftIndex >= n) {
        throw FormatException(
          'MatchPayload pairs: left index ${p.leftIndex} out of range',
        );
      }
      if (p.rightIndex < 0 || p.rightIndex >= n) {
        throw FormatException(
          'MatchPayload pairs: right index ${p.rightIndex} out of range',
        );
      }
      if (!leftSeen.add(p.leftIndex)) {
        throw FormatException(
          'MatchPayload pairs: duplicate left index ${p.leftIndex}',
        );
      }
      if (!rightSeen.add(p.rightIndex)) {
        throw FormatException(
          'MatchPayload pairs: duplicate right index ${p.rightIndex}',
        );
      }
    }
  }

  static List<MatchPair> _parsePairs(dynamic raw, int n) {
    if (raw is List) {
      return _pairsFromList(raw, n);
    }
    if (raw is Map) {
      return _pairsFromMap(raw, n);
    }
    throw FormatException('MatchPayload.pairs must be a JSON array or object');
  }

  static List<MatchPair> _pairsFromList(List<dynamic> raw, int n) {
    final out = <MatchPair>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is List) {
        if (e.length != 2) {
          throw FormatException(
            'MatchPayload.pairs[$i] must be a two-element array',
          );
        }
        out.add(
          MatchPair(
            leftIndex: _jsonInt(e[0], 'pairs[$i][0]'),
            rightIndex: _jsonInt(e[1], 'pairs[$i][1]'),
          ),
        );
        continue;
      }
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final li = _jsonInt(m['left'], 'pairs[$i].left');
        final ri = _jsonInt(m['right'], 'pairs[$i].right');
        out.add(MatchPair(leftIndex: li, rightIndex: ri));
        continue;
      }
      throw FormatException(
        'MatchPayload.pairs[$i] must be an array or object',
      );
    }
    return out;
  }

  static List<MatchPair> _pairsFromMap(Map raw, int n) {
    final entries = <MatchPair>[];
    for (final e in raw.entries) {
      final li = _jsonInt(e.key, 'pairs map key');
      final ri = _jsonInt(e.value, 'pairs[$li] value');
      entries.add(MatchPair(leftIndex: li, rightIndex: ri));
    }
    if (entries.length != n) {
      throw FormatException(
        'MatchPayload pairs object must have exactly $n keys',
      );
    }
    return entries;
  }

  static List<String> _reqStringList(
    Map<String, dynamic> json,
    String key, {
    required int minLen,
  }) {
    final v = json[key];
    if (v is! List) {
      throw FormatException('MatchPayload.$key must be a JSON array');
    }
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is! String) {
        throw FormatException('MatchPayload.$key[$i] must be a string');
      }
      final t = e.trim();
      if (t.isEmpty) {
        throw FormatException('MatchPayload.$key entries must be non-empty');
      }
      out.add(t);
    }
    if (out.length < minLen) {
      throw FormatException(
        'MatchPayload.$key must have at least $minLen items',
      );
    }
    return out;
  }

  static int _jsonInt(Object? e, String path) {
    if (e == null) {
      throw FormatException('MatchPayload.$path must be non-null');
    }
    if (e is int) return e;
    if (e is String) {
      final p = int.tryParse(e.trim());
      if (p == null) {
        throw FormatException('MatchPayload.$path must be an integer string');
      }
      return p;
    }
    if (e is double) {
      final r = e.round();
      if ((e - r).abs() > 1e-9) {
        throw FormatException('MatchPayload.$path must be a whole number');
      }
      return r;
    }
    throw FormatException('MatchPayload.$path must be a number');
  }
}
