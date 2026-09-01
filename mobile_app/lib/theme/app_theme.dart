import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Spotify Dark Color Palette
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF181818);
  static const Color cardColor = Color(0xFF242424);
  static const Color elevatedCardColor = Color(0xFF2A2A2A);
  static const Color primaryAccent = Color(0xFF1DB954); // Spotify Green
  static const Color secondaryAccent = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF727272);

  static ThemeData get spotifyTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryAccent,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: primaryAccent,
        surface: surfaceColor,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        titleMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.w400),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
      ),
    );
  }
}
