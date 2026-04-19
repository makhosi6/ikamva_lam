import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/tasks/cloze_payload.dart';
import '../domain/tasks/pronunciation_intonation_payload.dart';
import '../domain/tasks/read_aloud_payload.dart';

/// Stable dedupe key for cloze stems (TASKS §8.3).
String? contentHashForClozePayloadJson(String payloadJson) {
  final c = ClozePayload.tryParseJsonString(payloadJson);
  if (c == null) return null;
  final key =
      '${c.sentence.trim().toLowerCase()}|${c.answer.trim().toLowerCase()}';
  return sha256.convert(utf8.encode(key)).toString();
}

String? contentHashForReadAloudPayloadJson(String payloadJson) {
  final p = ReadAloudPayload.tryParseJsonString(payloadJson);
  if (p == null) return null;
  final key = p.displayText.trim().toLowerCase();
  return sha256.convert(utf8.encode(key)).toString();
}

String? contentHashForPronunciationPayloadJson(String payloadJson) {
  final p = PronunciationIntonationPayload.tryParseJsonString(payloadJson);
  if (p == null) return null;
  final key =
      '${p.question.trim().toLowerCase()}|${p.correctIndex}|${p.options.join("|")}';
  return sha256.convert(utf8.encode(key)).toString();
}
