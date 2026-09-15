import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'host_is_android.dart';

/// Spec / TASKS §6.6 — bounded context and completion length.
abstract final class LlmLimits {
  /// Allowed context window (tokens), clamped to \[512, 1024\] on most hosts.
  ///
  /// **Android:** upper bound is **512** for LiteRT stability (see
  /// [ModelPrepareConfig.contextMaxTokensFor]); `lowRamProfile` does not raise
  /// the cap there.
  static int clampContext(int requested, {required bool lowRamProfile}) {
    final android = !kIsWeb &&
        (hostIsAndroid || defaultTargetPlatform == TargetPlatform.android);
    final cap = android ? 512 : (lowRamProfile ? 512 : 768);
    final maxAllowed = android ? 512 : 1024;
    final raw = requested <= 0 ? cap : requested;
    if (raw < 512) return 512;
    if (raw > maxAllowed) return maxAllowed;
    return raw;
  }

  /// Default max new tokens (~120 per TASKS §6.6).
  static const int defaultMaxNewTokens = 120;

  static int clampMaxNewTokens(int requested) {
    if (requested <= 0) return defaultMaxNewTokens;
    if (requested > 256) return 256;
    return requested;
  }
}
