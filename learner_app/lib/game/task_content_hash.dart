import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/tasks/cloze_payload.dart';

/// Stable dedupe key for cloze stems (TASKS §8.3).
String? contentHashForClozePayloadJson(String payloadJson) {
  final c = ClozePayload.tryParseJsonString(payloadJson);
  if (c == null) return null;
  final key =
      '${c.sentence.trim().toLowerCase()}|${c.answer.trim().toLowerCase()}';
  return sha256.convert(utf8.encode(key)).toString();
}
