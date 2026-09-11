import 'package:flutter/material.dart';

class BeautyAppTheme {
  static const Color background = Color(0xFF141417);
  static const Color surface = Color(0xFF19191D);
  static const Color surfaceSecondary = Color(0xFF222226);
  static const Color accent = Color(0xFFFF7597);
  static const Color accentLight = Color(0xFFFF8DA1);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: surface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSecondary,
        selectedColor: accent.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white70),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      fontFamily: 'Inter',
      useMaterial3: true,
    );
  }
}
