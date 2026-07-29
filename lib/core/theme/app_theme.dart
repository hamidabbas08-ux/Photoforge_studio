import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF090B10);
  static const Color surface = Color(0xFF12151C);
  static const Color surfaceLight = Color(0xFF1A1E27);
  static const Color primary = Color(0xFF8B7CFF);
  static const Color secondary = Color(0xFF32D5C4);
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9DA3B2);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: textPrimary,
      ),
      dividerColor: Colors.white10,
      iconTheme: const IconThemeData(color: textPrimary),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: Colors.white12,
        thumbColor: Colors.white,
        overlayColor: primary.withValues(alpha: 0.14),
      ),
    );
  }
}
