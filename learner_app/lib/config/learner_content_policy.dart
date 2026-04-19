import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../domain/task_source.dart';

/// Which [TaskRecords] rows may be shown in learner play (spec §4.1.1, TASKS §8.6).
///
/// Release builds serve only **AI-produced** rows (`generated`, `cached_generated`).
/// Dev / profile builds allow **dev seeds** unless `ALLOW_DEV_SEED=false` is set at
/// compile time. Tests may set [debugAllowDevSeedOverride].
class LearnerContentPolicy {
  LearnerContentPolicy._();

  /// When non-null, overrides [allowDevSeed] (tests only).
  static bool? debugAllowDevSeedOverride;

  static bool get allowDevSeed {
    if (debugAllowDevSeedOverride != null) {
      return debugAllowDevSeedOverride!;
    }
    const envAllow = bool.fromEnvironment(
      'ALLOW_DEV_SEED',
      defaultValue: false,
    );
    if (envAllow) return true;
    if (kReleaseMode) return false;
    return true;
  }

  /// SQL predicate: learner-visible task rows.
  static Expression<bool> taskRowAllowed($TaskRecordsTable t) {
    if (allowDevSeed) {
      return const Constant(true);
    }
    return t.source.isIn([
      TaskSource.generated.storageValue,
      TaskSource.cachedGenerated.storageValue,
    ]);
  }
}
