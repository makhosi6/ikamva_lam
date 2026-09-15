import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Session debug ingest (see Cursor debug mode). On device use:
/// `adb reverse tcp:7388 tcp:7388`
const _kIngestUrl =
    'http://127.0.0.1:7388/ingest/8c95a891-3c99-48cc-97a6-e1b4a9ffb426';
const _kSessionId = '669518';

void agentDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  final payload = <String, Object?>{
    'sessionId': _kSessionId,
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  // #region agent log
  debugPrint('AGENT_DEBUG ${jsonEncode(payload)}');
  unawaited(
    http
        .post(
          Uri.parse(_kIngestUrl),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': _kSessionId,
          },
          body: jsonEncode(payload),
        )
        .catchError((_) => http.Response('', 500)),
  );
  // #endregion
}
