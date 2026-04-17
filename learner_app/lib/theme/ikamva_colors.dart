import 'package:flutter/material.dart';

/// Design tokens from project design.md (§5.2).
@immutable
class IkamvaColors extends ThemeExtension<IkamvaColors> {
  const IkamvaColors({
    required this.canvas,
    required this.card,
    required this.accentSun,
    required this.accentSky,
    required this.success,
    required this.warning,
    required this.error,
    required this.textSecondary,
  });

  final Color canvas;
  final Color card;
  final Color accentSun;
  final Color accentSky;
  final Color success;
  final Color warning;
  final Color error;
  final Color textSecondary;

  static const IkamvaColors light = IkamvaColors(
    canvas: Color(0xFFF6F1E7),
    card: Color(0xFFFFFFFF),
    accentSun: Color(0xFFE8A23E),
    accentSky: Color(0xFF3A7CA5),
    success: Color(0xFF2F8F6B),
    warning: Color(0xFFC47A00),
    error: Color(0xFFB3261E),
    textSecondary: Color(0xFF5C574C),
  );

  @override
  IkamvaColors copyWith({
    Color? canvas,
    Color? card,
    Color? accentSun,
    Color? accentSky,
    Color? success,
    Color? warning,
    Color? error,
    Color? textSecondary,
  }) {
    return IkamvaColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      accentSun: accentSun ?? this.accentSun,
      accentSky: accentSky ?? this.accentSky,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  ThemeExtension<IkamvaColors> lerp(
    ThemeExtension<IkamvaColors>? other,
    double t,
  ) {
    if (other is! IkamvaColors) return this;
    return IkamvaColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      accentSun: Color.lerp(accentSun, other.accentSun, t)!,
      accentSky: Color.lerp(accentSky, other.accentSky, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

extension IkamvaColorsX on BuildContext {
  IkamvaColors get ikamvaColors =>
      Theme.of(this).extension<IkamvaColors>() ?? IkamvaColors.light;
}
