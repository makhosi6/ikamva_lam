import 'package:flutter/services.dart';

import '../domain/task_type.dart';
import 'prompt_bundle.dart';
import 'prompt_slots.dart';
import 'slot_substitution.dart';
import 'topic_vocab_table.dart';

int levelMaxWordsHint(String level) {
  switch (level.trim().toUpperCase()) {
    case 'A1':
      return 8;
    case 'A2':
      return 12;
    case 'B1':
      return 15;
    default:
      return 18;
  }
}

/// Loads versioned prompt assets and fills `{{SLOTS}}` (TASKS §7.1–7.6).
class PromptComposer {
  PromptComposer({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  TopicVocabTable? _vocabCache;

  Future<String> _load(String fileName) =>
      _bundle.loadString(PromptBundle.assetPath(fileName));

  Future<TopicVocabTable> _vocab() async =>
      _vocabCache ??= TopicVocabTable.parse(await _load('topic_vocab.txt'));

  Future<Map<String, String>> _generationSlots(PromptSlots s) async {
    final vocab = (await _vocab()).vocabForTopic(s.topic);
    return {
      'LEVEL': s.level,
      'TOPIC': s.topic,
      'SKILL': s.skill,
      'DIFFICULTY_STEP': s.difficultyStep,
      'TOPIC_VOCAB': vocab,
      'LEVEL_MAX_WORDS': '${levelMaxWordsHint(s.level)}',
    };
  }

  String _taskBodyFile(TaskType type) => switch (type) {
        TaskType.cloze => 'generate_cloze.txt',
        TaskType.reorder => 'generate_reorder.txt',
        TaskType.match => 'generate_match.txt',
        TaskType.dialogueChoice => 'generate_dialogue_choice.txt',
        TaskType.readAloud => 'generate_read_aloud.txt',
        TaskType.pronunciationIntonation =>
          'generate_pronunciation_intonation.txt',
      };

  /// Preamble (pedagogy) + task-specific `generate_*` body.
  Future<String> composeGenerationPrompt(
    TaskType type,
    PromptSlots slots,
  ) async {
    final slotMap = await _generationSlots(slots);
    final preamble = applyPromptSlots(
      await _load('pedagogy_preamble.txt'),
      slotMap,
    );
    final body = applyPromptSlots(
      await _load(_taskBodyFile(type)),
      slotMap,
    );
    return '$preamble\n\n$body';
  }

  Future<String> composeHintPrompt({
    required String taskJson,
    required String wrongAnswer,
  }) async {
    final raw = await _load('hint_multilingual.txt');
    return applyPromptSlots(raw, {
      'TASK_JSON': taskJson,
      'WRONG_ANSWER': wrongAnswer,
    });
  }

  /// Spec §5.2 — optional normalisation path (TASKS §7.5).
  Future<String> composeNormaliseAnswerPrompt({
    required String taskJson,
    required String learnerText,
  }) async {
    final raw = await _load('normalise_answer.txt');
    return applyPromptSlots(raw, {
      'TASK_JSON': taskJson,
      'LEARNER_TEXT': learnerText,
    });
  }

  /// Teacher insight JSON (spec §6.2, TASKS §7.6).
  Future<String> composeInsightPrompt(String aggregatedStatsJson) async {
    final raw = await _load('insight_teacher.txt');
    return applyPromptSlots(raw, {
      'AGGREGATED_STATS_JSON': aggregatedStatsJson,
    });
  }
}
