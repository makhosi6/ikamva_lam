import 'dart:convert';

import '../db/app_database.dart';
import '../domain/task_type.dart';
import '../domain/tasks/cloze_payload.dart';
import '../domain/tasks/dialogue_choice_payload.dart';
import '../domain/tasks/match_payload.dart';
import '../domain/tasks/pronunciation_intonation_payload.dart';
import '../domain/tasks/reorder_payload.dart';

/// Outcome of comparing a learner answer to the task payload (TASKS §4.3).
class EvaluationResult {
  const EvaluationResult({required this.correct});

  final bool correct;
}

/// Rule-based scoring per task type (no model calls).
///
/// Learner answers are JSON strings. Supported shapes:
/// - **cloze:** `{"choice":"eat"}` or `{"selected":"eat"}` (trimmed, case-insensitive vs canonical answer).
/// - **reorder:** `{"order":[1,0,2]}` — must match `correct_order`.
/// - **match:** `{"pairs":[[0,0],[1,1]]}` or list of `{"left":0,"right":0}` — must match canonical pairs as a set.
/// - **dialogue_choice:** `{"index":0}` or `{"id":"a"}`.
/// - **read_aloud:** `{"completed":true}` (lightweight completion signal).
/// - **pronunciation_intonation:** `{"index":0}` (MCQ).
class RuleBasedEvaluator {
  const RuleBasedEvaluator();

  EvaluationResult evaluate(TaskRecord task, String learnerAnswerJson) {
    final type = TaskType.tryParse(task.taskType);
    if (type == null) return const EvaluationResult(correct: false);

    try {
      switch (type) {
        case TaskType.cloze:
          return _cloze(task.payloadJson, learnerAnswerJson);
        case TaskType.reorder:
          return _reorder(task.payloadJson, learnerAnswerJson);
        case TaskType.match:
          return _match(task.payloadJson, learnerAnswerJson);
        case TaskType.dialogueChoice:
          return _dialogue(task.payloadJson, learnerAnswerJson);
        case TaskType.readAloud:
          return _readAloud(learnerAnswerJson);
        case TaskType.pronunciationIntonation:
          return _pronunciation(task.payloadJson, learnerAnswerJson);
      }
    } on Object {
      return const EvaluationResult(correct: false);
    }
  }

  EvaluationResult _cloze(String payloadJson, String learnerAnswerJson) {
    final payload = ClozePayload.tryParseJsonString(payloadJson);
    if (payload == null) return const EvaluationResult(correct: false);

    final choice = _extractClozeChoice(learnerAnswerJson);
    if (choice == null) return const EvaluationResult(correct: false);

    final a = _norm(payload.answer);
    final b = _norm(choice);
    return EvaluationResult(correct: a == b);
  }

  String? _extractClozeChoice(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String) return decoded;
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['choice', 'selected', 'answer', 'value']) {
          final v = decoded[key];
          if (v is String && v.trim().isNotEmpty) return v;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  EvaluationResult _reorder(String payloadJson, String learnerAnswerJson) {
    final payload = ReorderPayload.tryParseJsonString(payloadJson);
    if (payload == null) return const EvaluationResult(correct: false);

    final order = _extractIntList(learnerAnswerJson, const ['order', 'permutation', 'correct_order']);
    if (order == null || order.length != payload.correctOrder.length) {
      return const EvaluationResult(correct: false);
    }
    for (var i = 0; i < order.length; i++) {
      if (order[i] != payload.correctOrder[i]) {
        return const EvaluationResult(correct: false);
      }
    }
    return const EvaluationResult(correct: true);
  }

  EvaluationResult _match(String payloadJson, String learnerAnswerJson) {
    final payload = MatchPayload.tryParseJsonString(payloadJson);
    if (payload == null) return const EvaluationResult(correct: false);

    final learnerPairs = _parseLearnerMatchPairs(learnerAnswerJson, payload.left.length);
    if (learnerPairs == null) return const EvaluationResult(correct: false);

    final canon = _canonicalPairKeys(payload.pairs);
    final learnerKeys = _pairKeys(learnerPairs);
    return EvaluationResult(
      correct: canon.length == learnerKeys.length &&
          canon.containsAll(learnerKeys),
    );
  }

  Set<String> _canonicalPairKeys(List<MatchPair> pairs) {
    return {for (final p in pairs) '${p.leftIndex}:${p.rightIndex}'};
  }

  Set<String> _pairKeys(Set<List<int>> pairs) {
    return {for (final p in pairs) '${p[0]}:${p[1]}'};
  }

  Set<List<int>>? _parseLearnerMatchPairs(String raw, int n) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final pr = map['pairs'];
      if (pr is! List) return null;
      final out = <List<int>>{};
      for (final e in pr) {
        if (e is List && e.length == 2) {
          final a = _asInt(e[0]);
          final b = _asInt(e[1]);
          if (a == null || b == null) return null;
          if (a < 0 || a >= n || b < 0 || b >= n) return null;
          out.add([a, b]);
          continue;
        }
        if (e is Map<String, dynamic>) {
          final a = _asInt(e['left']);
          final b = _asInt(e['right']);
          if (a == null || b == null) return null;
          if (a < 0 || a >= n || b < 0 || b >= n) return null;
          out.add([a, b]);
          continue;
        }
        return null;
      }
      return out;
    } on Object {
      return null;
    }
  }

  EvaluationResult _readAloud(String learnerAnswerJson) {
    try {
      final decoded = jsonDecode(learnerAnswerJson.trim());
      if (decoded is! Map) return const EvaluationResult(correct: false);
      final map = Map<String, dynamic>.from(decoded);
      final done = map['completed'] == true ||
          map['read_aloud_done'] == true ||
          map['done'] == true;
      return EvaluationResult(correct: done);
    } on Object {
      return const EvaluationResult(correct: false);
    }
  }

  EvaluationResult _pronunciation(String payloadJson, String learnerAnswerJson) {
    final payload = PronunciationIntonationPayload.tryParseJsonString(payloadJson);
    if (payload == null) return const EvaluationResult(correct: false);
    try {
      final decoded = jsonDecode(learnerAnswerJson.trim());
      if (decoded is! Map) {
        return const EvaluationResult(correct: false);
      }
      final map = Map<String, dynamic>.from(decoded);
      final idx = _asInt(
        map['index'] ?? map['selectedIndex'] ?? map['choice_index'],
      );
      if (idx == null) return const EvaluationResult(correct: false);
      return EvaluationResult(correct: idx == payload.correctIndex);
    } on Object {
      return const EvaluationResult(correct: false);
    }
  }

  EvaluationResult _dialogue(String payloadJson, String learnerAnswerJson) {
    final payload = DialogueChoicePayload.tryParseJsonString(payloadJson);
    if (payload == null) return const EvaluationResult(correct: false);

    try {
      final decoded = jsonDecode(learnerAnswerJson.trim());
      if (decoded is! Map) {
        return const EvaluationResult(correct: false);
      }
      final map = Map<String, dynamic>.from(decoded);
      if (payload.correctIndex != null) {
        final idx = _asInt(
          map['index'] ??
              map['selectedIndex'] ??
              map['choice_index'],
        );
        if (idx == null) return const EvaluationResult(correct: false);
        return EvaluationResult(
          correct: idx == payload.resolvedCorrectIndex,
        );
      }
      final id = _asString(
        map['id'] ?? map['selectedId'] ?? map['choice_id'],
      );
      if (id == null) return const EvaluationResult(correct: false);
      final expected = payload.correctId;
      if (expected == null) return const EvaluationResult(correct: false);
      return EvaluationResult(correct: _norm(id) == _norm(expected));
    } on Object {
      return const EvaluationResult(correct: false);
    }
  }

  List<int>? _extractIntList(String raw, List<String> keys) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      for (final key in keys) {
        final v = map[key];
        if (v is List) {
          final out = <int>[];
          for (final e in v) {
            final i = _asInt(e);
            if (i == null) return null;
            out.add(i);
          }
          return out;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) {
      final r = v.round();
      if ((v - r).abs() > 1e-9) return null;
      return r;
    }
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String? _asString(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static String _norm(String s) => s.trim().toLowerCase();
}
