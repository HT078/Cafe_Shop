import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color charColor = Color(0xFF241812);
  static const Color surfaceColor = Color(0xFF33231B);
  static const Color surfaceAltColor = Color(0xFF3D2A20);
  static const Color lineColor = Color(0xFF4A362C);
  static const Color creamColor = Color(0xFFF3E6D6);
  static const Color mutedColor = Color(0xFFA78B7A);
  static const Color emberColor = Color(0xFFFF7A29);
  static const Color blazeColor = Color(0xFFC81E2C);
  static const Color goldColor = Color(0xFFE8A93C);

  static const LinearGradient flameGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldColor, emberColor, blazeColor],
  );

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.mulishTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
      ),
    );

    final headingTextTheme = GoogleFonts.beVietnamProTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: charColor,
      colorScheme: const ColorScheme.dark(
        primary: emberColor,
        secondary: goldColor,
        surface: surfaceColor,
        surfaceContainerHighest: surfaceAltColor,
        onSurface: creamColor,
        outline: lineColor,
        primaryContainer: surfaceAltColor,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: headingTextTheme.headlineLarge?.copyWith(
          color: creamColor,
        ),
        headlineMedium: headingTextTheme.headlineMedium?.copyWith(
          color: creamColor,
        ),
        titleLarge: headingTextTheme.titleLarge?.copyWith(color: creamColor),
        titleMedium: headingTextTheme.titleMedium?.copyWith(color: creamColor),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: creamColor),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: creamColor),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: mutedColor),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: charColor,
        foregroundColor: creamColor,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emberColor,
          foregroundColor: charColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emberColor),
        ),
      ),
      dividerColor: lineColor,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A0E0A),
        selectedItemColor: goldColor,
        unselectedItemColor: mutedColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
