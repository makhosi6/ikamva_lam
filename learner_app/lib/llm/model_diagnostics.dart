import 'dart:convert';

import 'package:flutter/foundation.dart';

class ModelDiagnosticEvent {
  const ModelDiagnosticEvent({
    required this.timestamp,
    required this.area,
    required this.action,
    required this.message,
    this.data = const <String, Object?>{},
  });

  final DateTime timestamp;
  final String area;
  final String action;
  final String message;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toIso8601String(),
    'area': area,
    'action': action,
    'message': message,
    'data': data,
  };
}

/// In-memory verbose diagnostics for model download/load/probe flows.
/// Debug screen can render and copy this timeline for bug reports.
class ModelDiagnostics {
  ModelDiagnostics._();
  static final ModelDiagnostics instance = ModelDiagnostics._();

  final ValueNotifier<List<ModelDiagnosticEvent>> events =
      ValueNotifier<List<ModelDiagnosticEvent>>(<ModelDiagnosticEvent>[]);

  static const int _maxEvents = 500;

  void log({
    required String area,
    required String action,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final next = List<ModelDiagnosticEvent>.from(events.value)
      ..add(
        ModelDiagnosticEvent(
          timestamp: DateTime.now(),
          area: area,
          action: action,
          message: message,
          data: data,
        ),
      );
    if (next.length > _maxEvents) {
      next.removeRange(0, next.length - _maxEvents);
    }
    events.value = next;
    if (kDebugMode) {
      debugPrint(
        'ModelDiagnostics [$area/$action] $message '
        '${data.isEmpty ? '' : jsonEncode(data)}',
      );
    }
  }

  void clear() {
    events.value = <ModelDiagnosticEvent>[];
  }

  String asPrettyJson() {
    final payload = events.value.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
