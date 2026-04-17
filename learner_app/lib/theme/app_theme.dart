import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ikamva_colors.dart';

/// Primary teal-green from design.md.
const Color _primary = Color(0xFF1B6B5C);
const Color _onPrimary = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1C1B16);

ThemeData buildIkamvaTheme({required Brightness brightness}) {
  final ikamva = IkamvaColors.light;
  final colorScheme = ColorScheme.light(
    primary: _primary,
    onPrimary: _onPrimary,
    secondary: ikamva.accentSky,
    onSecondary: Colors.white,
    surface: ikamva.card,
    onSurface: _textPrimary,
    error: ikamva.error,
    onError: Colors.white,
  );

  final displayTextStyle = GoogleFonts.nunito(
    color: _textPrimary,
    fontWeight: FontWeight.w700,
  );
  final bodyTextStyle = GoogleFonts.sourceSans3(
    color: _textPrimary,
    height: 1.35,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: ikamva.canvas,
    extensions: const [IkamvaColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: ikamva.canvas,
      foregroundColor: _textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.nunito(
        color: _textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: ikamva.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        minimumSize: const Size(double.infinity, 56),
        textStyle: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: displayTextStyle.copyWith(fontSize: 40),
      displayMedium: displayTextStyle.copyWith(fontSize: 32),
      displaySmall: displayTextStyle.copyWith(fontSize: 26),
      headlineLarge: displayTextStyle.copyWith(fontSize: 24),
      headlineMedium: displayTextStyle.copyWith(fontSize: 22),
      headlineSmall: displayTextStyle.copyWith(fontSize: 20),
      titleLarge: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
      ),
      titleMedium: GoogleFonts.sourceSans3(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      bodyLarge: bodyTextStyle.copyWith(fontSize: 20),
      bodyMedium: bodyTextStyle.copyWith(fontSize: 18),
      bodySmall: bodyTextStyle.copyWith(
        fontSize: 16,
        color: ikamva.textSecondary,
      ),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _primary,
      ),
    ),
  );
}
