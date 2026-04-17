import 'dart:convert';
import 'dart:developer' as developer;

import '../task_type.dart';
import 'cloze_payload.dart';
import 'dialogue_choice_payload.dart';
import 'match_payload.dart';
import 'reorder_payload.dart';

/// Rewrites legacy / sloppy JSON into the canonical maps expected by
/// `*Payload.fromJson` (TASKS §3.6). Logs recoverable issues and rejectsions
/// for prompt tuning.
class TaskNormalizer {
  TaskNormalizer({void Function(String message)? log}) : _log = log ?? _defaultLog;

  final void Function(String) _log;

  static void _defaultLog(String message) {
    developer.log(message, name: 'TaskNormalizer');
  }

  /// Decodes JSON text then [normalizeDecoded].
  Map<String, dynamic>? normalizeJson(TaskType type, String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _log('TaskNormalizer: root must be a JSON object for ${type.storageValue}');
        return null;
      }
      return normalizeDecoded(type, Map<String, dynamic>.from(decoded));
    } on FormatException catch (e) {
      _log('TaskNormalizer: JSON decode failed for ${type.storageValue}: $e');
      return null;
    } on Object catch (e) {
      _log('TaskNormalizer: unexpected error for ${type.storageValue}: $e');
      return null;
    }
  }

  /// Returns a **new** canonical map, or `null` if the payload cannot be
  /// coerced into a shape accepted by the typed parser.
  Map<String, dynamic>? normalizeDecoded(
    TaskType type,
    Map<String, dynamic> raw,
  ) {
    final flat = _stringKeyMap(raw);
    switch (type) {
      case TaskType.cloze:
        return _normalizeCloze(flat);
      case TaskType.reorder:
        return _normalizeReorder(flat);
      case TaskType.match:
        return _normalizeMatch(flat);
      case TaskType.dialogueChoice:
        return _normalizeDialogue(flat);
    }
  }

  Map<String, dynamic> _stringKeyMap(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic>? _normalizeCloze(Map<String, dynamic> r) {
    final sentence = _firstString(r, const [
      'sentence',
      'stem',
      'prompt',
      'text',
    ]);
    final answer = _firstString(r, const [
      'answer',
      'correct_answer',
      'correctAnswer',
      'gap_answer',
      'solution',
    ]);
    final optionsRaw = _firstList(r, const ['options', 'choices', 'distractors']);
    if (sentence == null || answer == null) {
      _log(
        'TaskNormalizer[cloze]: missing sentence or answer (keys: ${r.keys.toList()})',
      );
      return null;
    }
    if (optionsRaw == null) {
      _log('TaskNormalizer[cloze]: missing options/choices');
      return null;
    }
    List<String>? options = _coerceStringList(optionsRaw, 'options');
    if (options == null) {
      _log('TaskNormalizer[cloze]: options must be strings');
      return null;
    }
    if (options.length < 3) {
      final merged = _mergeAnswerIntoOptions(options, answer);
      if (merged != null) {
        _log('TaskNormalizer[cloze]: merged answer into short distractor list');
        options = merged;
      }
    }
    final out = <String, dynamic>{
      'sentence': sentence,
      'answer': answer,
      'options': options,
    };
    _copyOptionalHintKeys(r, out);
    return _verifyCloze(out);
  }

  List<String>? _mergeAnswerIntoOptions(List<String> opts, String answer) {
    if (opts.length < 2 || opts.length > 3) return null;
    final fold = answer.trim().toLowerCase();
    final has = opts.any((o) => o.trim().toLowerCase() == fold);
    if (has) return opts;
    return [...opts, answer];
  }

  void _copyOptionalHintKeys(Map<String, dynamic> r, Map<String, dynamic> out) {
    const keys = ['hint_en', 'hint_xh', 'hint_zu', 'hint_af'];
    const camel = ['hintEn', 'hintXh', 'hintZu', 'hintAf'];
    for (var i = 0; i < keys.length; i++) {
      final v = r[keys[i]] ?? r[camel[i]];
      if (v is String && v.trim().isNotEmpty) out[keys[i]] = v.trim();
    }
  }

  Map<String, dynamic>? _verifyCloze(Map<String, dynamic> out) {
    try {
      ClozePayload.fromJson(out);
      return out;
    } on FormatException catch (e) {
      _log('TaskNormalizer[cloze]: parser rejected normalized map: $e');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeReorder(Map<String, dynamic> r) {
    final tokens = _firstList(r, const [
      'tokens',
      'pieces',
      'words',
      'fragments',
    ]);
    final order = _firstList(r, const [
      'correct_order',
      'correctOrder',
      'order',
      'target_order',
      'permutation',
    ]);
    if (tokens == null || order == null) {
      _log(
        'TaskNormalizer[reorder]: missing tokens or order (keys: ${r.keys.toList()})',
      );
      return null;
    }
    final tokStr = _coerceStringList(tokens, 'tokens');
    final ordInt = _coerceIntList(order, 'correct_order');
    if (tokStr == null || ordInt == null) return null;
    final out = <String, dynamic>{
      'tokens': tokStr,
      'correct_order': ordInt,
    };
    try {
      ReorderPayload.fromJson(out);
      return out;
    } on FormatException catch (e) {
      _log('TaskNormalizer[reorder]: parser rejected: $e');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeMatch(Map<String, dynamic> r) {
    final left = _firstList(r, const ['left', 'left_column', 'leftLabels']);
    final right = _firstList(r, const ['right', 'right_column', 'rightLabels']);
    final pairsRaw = r['pairs'] ?? r['links'] ?? r['solution'] ?? r['mapping'];
    if (left == null || right == null || pairsRaw == null) {
      _log(
        'TaskNormalizer[match]: missing left, right, or pairs (keys: ${r.keys.toList()})',
      );
      return null;
    }
    final l = _coerceStringList(left, 'left');
    final rt = _coerceStringList(right, 'right');
    if (l == null || rt == null) return null;
    final out = <String, dynamic>{'left': l, 'right': rt, 'pairs': pairsRaw};
    try {
      MatchPayload.fromJson(out);
      return out;
    } on FormatException catch (e) {
      _log('TaskNormalizer[match]: parser rejected: $e');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeDialogue(Map<String, dynamic> r) {
    final context = _firstString(r, const [
      'context',
      'scenario',
      'setting',
      'scene',
    ]);
    final question = _firstString(r, const [
      'question',
      'prompt',
      'body',
      'ask',
    ]);
    final options = r['options'] ?? r['choices'] ?? r['answers'];
    if (context == null || question == null || options == null) {
      _log(
        'TaskNormalizer[dialogue]: missing context, question, or options',
      );
      return null;
    }
    final out = <String, dynamic>{
      'context': context,
      'question': question,
      'options': options,
    };
    final ci = r['correct_index'] ?? r['correctIndex'];
    final cid = r['correct_id'] ?? r['correctId'];
    if (cid is String && cid.trim().isNotEmpty) {
      out['correct_id'] = cid.trim();
    } else if (ci != null) {
      final idx = ci is int ? ci : int.tryParse('$ci');
      if (idx != null) {
        out['correct_index'] = idx;
      }
    }
    try {
      DialogueChoicePayload.fromJson(out);
      return out;
    } on FormatException catch (e) {
      _log('TaskNormalizer[dialogue]: parser rejected: $e');
      return null;
    }
  }

  String? _firstString(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  List<dynamic>? _firstList(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v is List && v.isNotEmpty) return v;
    }
    return null;
  }

  List<String>? _coerceStringList(List<dynamic> raw, String field) {
    final out = <String>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is! String) {
        _log('TaskNormalizer: $field[$i] must be string');
        return null;
      }
      if (e.trim().isEmpty) {
        _log('TaskNormalizer: $field[$i] empty');
        return null;
      }
      out.add(e.trim());
    }
    return out;
  }

  List<int>? _coerceIntList(List<dynamic> raw, String field) {
    final out = <int>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is int) {
        out.add(e);
        continue;
      }
      if (e is double) {
        out.add(e.round());
        continue;
      }
      if (e is String) {
        final p = int.tryParse(e.trim());
        if (p != null) {
          out.add(p);
          continue;
        }
      }
      _log('TaskNormalizer: $field[$i] not an int');
      return null;
    }
    return out;
  }
}
