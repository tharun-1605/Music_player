import 'package:flutter/material.dart';

class AppTheme {
  // ============================================================
  // AUDiOPHILIA BLUE / NOTHING-INSPIRED PALETTE
  // ============================================================

  static const Color backgroundColor = Color(0xFF050812);

  static const Color surfaceColor = Color(0xFF111827);

  static const Color cardColor = Color(0xFF111827);

  static const Color elevatedCardColor = Color(0xFF182136);

  // Main Audiophilia blue.
  static const Color primaryAccent = Color(0xFF5B8CFF);

  // Secondary violet-blue used for atmospheric effects.
  static const Color violetAccent = Color(0xFF7C6CFF);

  static const Color secondaryAccent = Colors.white;

  static const Color textPrimary = Color(0xFFFFFFFF);

  static const Color textSecondary = Color(0xFFB8C0D0);

  static const Color textMuted = Color(0xFF7D8494);

  static const Color borderColor = Color(0x2EFFFFFF);

  static const Color subtleBorder = Color(0x18FFFFFF);

  // ============================================================
  // BACKGROUND GRADIENT
  // ============================================================

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050812),
      Color(0xFF090D1A),
      Color(0xFF10152B),
      Color(0xFF080B16),
    ],
    stops: [
      0.0,
      0.35,
      0.70,
      1.0,
    ],
  );

  // Atmospheric blue glow.
  static const RadialGradient blueGlow = RadialGradient(
    center: Alignment(-0.7, -0.9),
    radius: 1.2,
    colors: [
      Color(0x335B8CFF),
      Color(0x105B8CFF),
      Colors.transparent,
    ],
  );

  // Secondary violet atmosphere.
  static const RadialGradient violetGlow = RadialGradient(
    center: Alignment(0.9, 0.5),
    radius: 1.3,
    colors: [
      Color(0x227C6CFF),
      Color(0x087C6CFF),
      Colors.transparent,
    ],
  );

  // ============================================================
  // TYPOGRAPHY
  // ============================================================

  static const TextStyle dotHeading = TextStyle(
    fontFamily: 'NDot57',
    color: textPrimary,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.5,
  );

  static const TextStyle typeHeading = TextStyle(
    fontFamily: 'NType82',
    color: textPrimary,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const TextStyle monoHeading = TextStyle(
    fontFamily: 'NType82Mono',
    color: textPrimary,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  static const TextStyle monoBody = TextStyle(
    fontFamily: 'NType82Mono',
    color: textSecondary,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // ============================================================
  // THEME
  // ============================================================

  static ThemeData get spotifyTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: backgroundColor,

      primaryColor: primaryAccent,

      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: violetAccent,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),

      fontFamily: 'NType82',

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'NDot57',
          color: textPrimary,
          fontSize: 36,
          letterSpacing: 1.5,
        ),

        displayMedium: TextStyle(
          fontFamily: 'NDot57',
          color: textPrimary,
          fontSize: 30,
          letterSpacing: 1.4,
        ),

        headlineLarge: TextStyle(
          fontFamily: 'NDot57',
          color: textPrimary,
          fontSize: 24,
          letterSpacing: 1.2,
        ),

        headlineMedium: TextStyle(
          fontFamily: 'NDot57',
          color: textPrimary,
          fontSize: 20,
          letterSpacing: 1.1,
        ),

        titleLarge: TextStyle(
          fontFamily: 'NType82',
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),

        titleMedium: TextStyle(
          fontFamily: 'NType82',
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),

        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          color: textPrimary,
          fontSize: 15,
        ),

        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          color: textSecondary,
          fontSize: 13,
        ),

        bodySmall: TextStyle(
          fontFamily: 'Inter',
          color: textMuted,
          fontSize: 11,
        ),

        labelLarge: TextStyle(
          fontFamily: 'NType82Mono',
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),

        labelMedium: TextStyle(
          fontFamily: 'NType82Mono',
          color: textSecondary,
          fontSize: 10,
        ),

        labelSmall: TextStyle(
          fontFamily: 'NType82Mono',
          color: textMuted,
          fontSize: 9,
        ),
      ),

      // ========================================================
      // CARDS
      // ========================================================

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(
            color: subtleBorder,
            width: 1,
          ),
        ),
      ),

      // ========================================================
      // APP BAR
      // ========================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,

        iconTheme: IconThemeData(
          color: textPrimary,
          size: 21,
        ),

        titleTextStyle: TextStyle(
          fontFamily: 'NDot57',
          color: textPrimary,
          fontSize: 20,
          letterSpacing: 1.4,
        ),
      ),

      // ========================================================
      // ICONS
      // ========================================================

      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 21,
      ),

      // ========================================================
      // DIVIDERS
      // ========================================================

      dividerTheme: const DividerThemeData(
        color: subtleBorder,
        thickness: 1,
        space: 1,
      ),

      // ========================================================
      // INPUTS
      // ========================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: primaryAccent,
          ),
        ),

        hintStyle: const TextStyle(
          fontFamily: 'NType82',
          color: textMuted,
          fontSize: 12,
        ),
      ),

      // ========================================================
      // BUTTONS
      // ========================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),

          textStyle: const TextStyle(
            fontFamily: 'NType82',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,

          side: const BorderSide(
            color: borderColor,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),

      // ========================================================
      // PROGRESS
      // ========================================================

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryAccent,
      ),

      // ========================================================
      // SNACKBAR
      // ========================================================

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceColor,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(4),
          ),
          side: BorderSide(
            color: borderColor,
          ),
        ),
      ),
    );
  }
}