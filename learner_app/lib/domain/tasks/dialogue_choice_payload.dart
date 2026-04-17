import 'dart:convert';

/// One selectable line in a dialogue-choice task.
class DialogueOption {
  const DialogueOption({required this.id, required this.text});

  /// Stable key for scoring (e.g. `a`, `opt_1`, or `0` when inferred from strings).
  final String id;

  /// Text shown on the choice chip.
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// Typed payload for a short dialogue / MCQ style task (TASKS §3.4).
///
/// Provide exactly one of [correctIndex] or [correctId] after parsing.
/// Stricter duplicate and length rules belong in Phase 3.5.
class DialogueChoicePayload {
  DialogueChoicePayload({
    required this.context,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.correctId,
  }) {
    final hasIndex = correctIndex != null;
    final hasId = correctId != null;
    if (hasIndex == hasId) {
      throw FormatException(
        'DialogueChoicePayload requires exactly one of correct_index or correct_id',
      );
    }
    if (options.length < 2) {
      throw FormatException(
        'DialogueChoicePayload.options must have at least 2 items',
      );
    }
    if (correctIndex != null) {
      if (correctIndex! < 0 || correctIndex! >= options.length) {
        throw FormatException(
          'DialogueChoicePayload.correctIndex out of range',
        );
      }
    } else {
      final id = correctId!;
      final match = options.where((o) => o.id == id).toList();
      if (match.length != 1) {
        throw FormatException(
          'DialogueChoicePayload.correctId must match exactly one option id',
        );
      }
    }
  }

  /// Short framing (scene, who is speaking, etc.).
  final String context;

  /// Prompt the learner answers.
  final String question;

  final List<DialogueOption> options;

  /// Zero-based index into [options] when the task was keyed by index.
  final int? correctIndex;

  /// Matches [DialogueOption.id] when the task was keyed by id.
  final String? correctId;

  /// Canonical index of the correct option (for evaluators).
  int get resolvedCorrectIndex {
    if (correctIndex != null) return correctIndex!;
    return options.indexWhere((o) => o.id == correctId);
  }

  static DialogueChoicePayload? tryParseJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return DialogueChoicePayload.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory DialogueChoicePayload.fromJson(Map<String, dynamic> json) {
    final context = _reqString(json, 'context');
    final question = _reqString(json, 'question');
    final options = _parseOptions(json['options']);
    final ci = json.containsKey('correct_index')
        ? _optInt(json['correct_index'], 'correct_index')
        : null;
    final cid = _optString(json, 'correct_id');
    if (ci == null && cid == null) {
      throw FormatException(
        'DialogueChoicePayload requires correct_index or correct_id',
      );
    }
    if (ci != null && cid != null) {
      throw FormatException(
        'DialogueChoicePayload must not set both correct_index and correct_id',
      );
    }
    return DialogueChoicePayload(
      context: context,
      question: question,
      options: options,
      correctIndex: ci,
      correctId: cid,
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'context': context,
      'question': question,
      'options': options.map((o) => o.toJson()).toList(),
    };
    if (correctIndex != null) {
      m['correct_index'] = correctIndex;
    } else {
      m['correct_id'] = correctId;
    }
    return m;
  }

  String toJsonString() => jsonEncode(toJson());

  static List<DialogueOption> _parseOptions(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      throw FormatException('DialogueChoicePayload.options must be a non-empty array');
    }
    final out = <DialogueOption>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is String) {
        final t = e.trim();
        if (t.isEmpty) {
          throw FormatException('DialogueChoicePayload.options[$i] must be non-empty');
        }
        out.add(DialogueOption(id: '$i', text: t));
        continue;
      }
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final id = _reqString(m, 'id');
        final text = m.containsKey('text')
            ? _reqString(m, 'text')
            : _reqString(m, 'label');
        out.add(DialogueOption(id: id, text: text));
        continue;
      }
      throw FormatException(
        'DialogueChoicePayload.options[$i] must be a string or object',
      );
    }
    return out;
  }

  static String _reqString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is! String) {
      throw FormatException('DialogueChoicePayload.$key must be a non-null string');
    }
    final t = v.trim();
    if (t.isEmpty) {
      throw FormatException('DialogueChoicePayload.$key must be non-empty');
    }
    return t;
  }

  static String? _optString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String) {
      throw FormatException('DialogueChoicePayload.$key must be a string or null');
    }
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static int? _optInt(dynamic v, String path) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) {
      final r = v.round();
      if ((v - r).abs() > 1e-9) {
        throw FormatException('DialogueChoicePayload.$path must be a whole number');
      }
      return r;
    }
    if (v is String) {
      final p = int.tryParse(v.trim());
      if (p == null) {
        throw FormatException('DialogueChoicePayload.$path must be an integer');
      }
      return p;
    }
    throw FormatException('DialogueChoicePayload.$path must be an integer');
  }
}
