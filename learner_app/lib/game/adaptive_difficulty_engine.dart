/// How the adaptive engine wants to move learner support (TASKS §5.3, spec §4.2).
enum DifficultyAdjustment {
  /// Raise difficulty step (rolling accuracy **above** [highThreshold]).
  harder,

  /// Lower difficulty step (below [lowThreshold], step &gt; 1).
  easier,

  /// At minimum step but still struggling — prefer hints first.
  enableHintFirst,

  /// Keep current step and hint policy.
  hold,
}

/// Spec §4.2: **&gt;80%** → harder; **&lt;50%** → more support (within quest caps).
class AdaptiveDifficultyEngine {
  const AdaptiveDifficultyEngine({
    this.highThreshold = 0.8,
    this.lowThreshold = 0.5,
  });

  /// Inclusive boundary: strictly **greater** than this triggers harder.
  final double highThreshold;

  /// Strictly **less** than this triggers easier / hint-first.
  final double lowThreshold;

  /// [rollingAccuracy] in \[0,1\], or null → [DifficultyAdjustment.hold].
  DifficultyAdjustment recommend({
    required double? rollingAccuracy,
    required int currentStep,
    required int maxStep,
    required bool hintFirstActive,
  }) {
    if (rollingAccuracy == null || rollingAccuracy.isNaN) {
      return DifficultyAdjustment.hold;
    }
    final r = rollingAccuracy.clamp(0.0, 1.0);
    if (r > highThreshold) {
      if (currentStep < maxStep) return DifficultyAdjustment.harder;
      return DifficultyAdjustment.hold;
    }
    if (r < lowThreshold) {
      if (currentStep > 1) return DifficultyAdjustment.easier;
      if (!hintFirstActive) return DifficultyAdjustment.enableHintFirst;
    }
    return DifficultyAdjustment.hold;
  }

  /// Applies [recommend] output to concrete persisted fields.
  ({int step, bool hintFirstMode}) apply({
    required DifficultyAdjustment adjustment,
    required int currentStep,
    required bool hintFirstMode,
    required int maxStep,
  }) {
    switch (adjustment) {
      case DifficultyAdjustment.harder:
        return (
          step: (currentStep + 1).clamp(1, maxStep),
          hintFirstMode: false,
        );
      case DifficultyAdjustment.easier:
        return (
          step: (currentStep - 1).clamp(1, maxStep),
          hintFirstMode: false,
        );
      case DifficultyAdjustment.enableHintFirst:
        return (step: currentStep.clamp(1, maxStep), hintFirstMode: true);
      case DifficultyAdjustment.hold:
        return (step: currentStep.clamp(1, maxStep), hintFirstMode: hintFirstMode);
    }
  }
}
