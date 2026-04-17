import 'package:flutter/foundation.dart';

/// Local analytics hook (TASKS §4.6). Replace with real telemetry later.
class IkamvaAnalytics {
  const IkamvaAnalytics();

  void recordAttemptOutcome({
    required String taskId,
    required String skillId,
    required bool correct,
    required bool usedHint,
  }) {
    if (kDebugMode) {
      debugPrint(
        '[IkamvaAnalytics] task=$taskId skill=$skillId correct=$correct hint=$usedHint',
      );
    }
  }
}
