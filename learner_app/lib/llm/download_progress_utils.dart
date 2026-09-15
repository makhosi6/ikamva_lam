/// Utilities for normalising download-progress values reported by various
/// Hugging Face download paths.
library;

/// Normalises a raw progress value [p] to the closed interval [0, 100].
///
/// Some download paths report **0–1** fractions; [DetailedSmartDownloader]
/// uses **0–100** integers.  The rule is:
///
/// * `NaN` or `Infinity` → `0`
/// * `p > 0 && p < 1`   → treated as a fraction; result is `p * 100` clamped
///   to [0, 100].  Strict `< 1` means `1` is interpreted as **1 %**, not 100 %.
/// * otherwise           → `p` clamped to [0, 100].
double normalizeHfPercent(double p) {
  if (p.isNaN || p.isInfinite) return 0;
  if (p > 0 && p < 1) return (p * 100).clamp(0, 100);
  return p.clamp(0, 100);
}
