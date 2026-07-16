import 'package:flutter/material.dart';

class AppTheme {
  static const Color charColor = Color(0xFF1A0A04);
  static const Color pageColor = Color(0xFFF7F4EF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceAltColor = Color(0xFFF5EEE7);
  static const Color surfaceRaisedColor = Color(0xFFFFF3D9);
  static const Color lineColor = Color(0xFFE4DAD2);
  static const Color lineSoftColor = Color(0xFFCDBBAE);
  static const Color creamColor = Color(0xFF2D1B13);
  static const Color lightTextColor = Color(0xFFFFF8F0);
  static const Color mutedColor = Color(0xFF74665E);
  static const Color emberColor = Color(0xFFF28A2E);
  static const Color blazeColor = Color(0xFFBD4A34);
  static const Color goldColor = Color(0xFFBA7517);
  static const Color successColor = Color(0xFF73C08D);
  static const Color warningColor = Color(0xFFF0BB62);
  static const Color dangerColor = Color(0xFFDE6A59);

  static const LinearGradient flameGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6B767), goldColor, emberColor],
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x22F3C878), Color(0x00FFFFFF)],
  );

  static ThemeData get appTheme {
    const baseTextTheme = TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
    );
    const headingTextTheme = baseTextTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: pageColor,
      colorScheme: const ColorScheme.light(
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
        foregroundColor: lightTextColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lineColor),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emberColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: goldColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: creamColor,
          side: const BorderSide(color: lineSoftColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: goldColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: goldColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        labelStyle: const TextStyle(color: mutedColor),
        hintStyle: const TextStyle(color: mutedColor),
        prefixIconColor: mutedColor,
        suffixIconColor: mutedColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerColor),
        ),
      ),
      dividerColor: lineColor,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaisedColor,
        contentTextStyle: const TextStyle(color: creamColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: lineSoftColor),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return goldColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(charColor),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return goldColor;
          return mutedColor;
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: goldColor,
        unselectedLabelColor: mutedColor,
        indicatorColor: emberColor,
        dividerColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: goldColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A0E0A),
        selectedItemColor: goldColor,
        unselectedItemColor: mutedColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Kept as a compatibility alias for older screens.
  static ThemeData get darkTheme => appTheme;
}
