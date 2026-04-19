import 'cefr_task_limits.dart';
import 'cloze_payload.dart';
import 'dialogue_choice_payload.dart';
import 'match_payload.dart';
import 'pronunciation_intonation_payload.dart';
import 'read_aloud_payload.dart';
import 'reorder_payload.dart';
import 'task_text_policy.dart' show countWords, duplicateFoldedStrings, stringsEqualIgnoreCase;

/// Manual validation on top of typed payloads (TASKS §3.5). Empty list ⇒ OK.
abstract final class TaskPayloadValidators {
  /// Returns human-readable issues; empty when the payload may be shown.
  static List<String> validateCloze(ClozePayload p, String? questLevel) {
    final issues = <String>[];
    final optCount = p.options.length;
    if (optCount < 3 || optCount > 4) {
      issues.add('cloze: expected 3–4 options, got $optCount');
    }
    final dup = duplicateFoldedStrings(p.options);
    if (dup.isNotEmpty) {
      issues.add('cloze: duplicate options (case-insensitive): ${dup.join(", ")}');
    }
    final answerInOptions = p.options.any(
      (o) => stringsEqualIgnoreCase(o, p.answer),
    );
    if (!answerInOptions) {
      issues.add('cloze: answer must appear in options list');
    }
    final maxSent = CefrTaskLimits.maxWordsClozeSentence(questLevel);
    final n = countWords(p.sentence);
    if (n > maxSent) {
      final lvl = CefrTaskLimits.normalizeLevel(questLevel);
      final lvlLabel = lvl.isEmpty ? 'default' : lvl;
      issues.add(
        'cloze: sentence has $n words (max $maxSent for $lvlLabel level)',
      );
    }
    return issues;
  }

  static List<String> validateReorder(ReorderPayload p, String? questLevel) {
    final issues = <String>[];
    final dup = duplicateFoldedStrings(p.tokens);
    if (dup.isNotEmpty) {
      issues.add('reorder: duplicate tokens (case-insensitive): ${dup.join(", ")}');
    }
    final maxTok = CefrTaskLimits.maxWordsReorderToken(questLevel);
    for (var i = 0; i < p.tokens.length; i++) {
      final w = countWords(p.tokens[i]);
      if (w > maxTok) {
        issues.add(
          'reorder: token[$i] has $w words (max $maxTok for this level)',
        );
      }
    }
    return issues;
  }

  static List<String> validateMatch(MatchPayload p, String? questLevel) {
    final issues = <String>[];
    final dupL = duplicateFoldedStrings(p.left);
    if (dupL.isNotEmpty) {
      issues.add('match: duplicate left labels: ${dupL.join(", ")}');
    }
    final dupR = duplicateFoldedStrings(p.right);
    if (dupR.isNotEmpty) {
      issues.add('match: duplicate right labels: ${dupR.join(", ")}');
    }
    final maxLab = CefrTaskLimits.maxWordsMatchLabel(questLevel);
    for (var i = 0; i < p.left.length; i++) {
      final wl = countWords(p.left[i]);
      if (wl > maxLab) {
        issues.add('match: left[$i] has $wl words (max $maxLab)');
      }
      final wr = countWords(p.right[i]);
      if (wr > maxLab) {
        issues.add('match: right[$i] has $wr words (max $maxLab)');
      }
    }
    return issues;
  }

  static List<String> validateDialogueChoice(
    DialogueChoicePayload p,
    String? questLevel,
  ) {
    final issues = <String>[];
    final texts = p.options.map((o) => o.text).toList();
    final dup = duplicateFoldedStrings(texts);
    if (dup.isNotEmpty) {
      issues.add(
        'dialogue: duplicate option text (case-insensitive): ${dup.join(", ")}',
      );
    }
    final dupIds = duplicateFoldedStrings(p.options.map((o) => o.id));
    if (dupIds.isNotEmpty) {
      issues.add('dialogue: duplicate option ids: ${dupIds.join(", ")}');
    }
    final maxB = CefrTaskLimits.maxWordsDialogueBlock(questLevel);
    final wc = countWords(p.context);
    if (wc > maxB) {
      issues.add('dialogue: context has $wc words (max $maxB)');
    }
    final wq = countWords(p.question);
    if (wq > maxB) {
      issues.add('dialogue: question has $wq words (max $maxB)');
    }
    for (var i = 0; i < p.options.length; i++) {
      final wo = countWords(p.options[i].text);
      if (wo > maxB) {
        issues.add('dialogue: option[$i] has $wo words (max $maxB)');
      }
    }
    return issues;
  }

  static List<String> validateReadAloud(ReadAloudPayload p, String? questLevel) {
    final issues = <String>[];
    final maxLine = CefrTaskLimits.maxWordsReadAloudLine(questLevel);
    final n = countWords(p.displayText);
    if (n > maxLine) {
      issues.add('read_aloud: display_text has $n words (max $maxLine)');
    }
    final ins = p.instructionEn;
    if (ins != null && countWords(ins) > maxLine) {
      issues.add('read_aloud: instruction too long');
    }
    return issues;
  }

  static List<String> validatePronunciationIntonation(
    PronunciationIntonationPayload p,
    String? questLevel,
  ) {
    final issues = <String>[];
    final maxQ = CefrTaskLimits.maxWordsProsodyQuestion(questLevel);
    final nq = countWords(p.question);
    if (nq > maxQ) {
      issues.add('pronunciation: question has $nq words (max $maxQ)');
    }
    final dup = duplicateFoldedStrings(p.options);
    if (dup.isNotEmpty) {
      issues.add(
        'pronunciation: duplicate options (case-insensitive): ${dup.join(", ")}',
      );
    }
    final maxOpt = maxQ;
    for (var i = 0; i < p.options.length; i++) {
      final w = countWords(p.options[i]);
      if (w > maxOpt) {
        issues.add('pronunciation: option[$i] has $w words (max $maxOpt)');
      }
    }
    return issues;
  }
}
