/// Spec / TASKS §6.6 — bounded context and completion length.
abstract final class LlmLimits {
  /// Allowed context window (tokens), clamped to \[512, 1024\].
  static int clampContext(int requested, {required bool lowRamProfile}) {
    final cap = lowRamProfile ? 512 : 768;
    final raw = requested <= 0 ? cap : requested;
    if (raw < 512) return 512;
    if (raw > 1024) return 1024;
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
