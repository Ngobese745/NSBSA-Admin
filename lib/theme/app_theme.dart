import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color darkBackground = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color textLight = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFFA0A0A0);

  // Light Theme Colors
  static const Color lightBackground = Color(
    0xFFF8F9FA,
  ); // Professional, very light grey background
  static const Color lightSurfaceColor = Color(
    0xFFFFFFFF,
  ); // Pure white for cards/surfaces
  static const Color textDark = Color(
    0xFF1A1A1A,
  ); // Soft black for high contrast but easy reading
  static const Color textMutedDark = Color(
    0xFF6C757D,
  ); // Clear, professional muted text

  static ThemeData get darkGoldTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryGold,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: primaryGold,
        surface: surfaceColor,
        background: darkBackground,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textLight,
        onBackground: textLight,
      ),
      textTheme: baseTextTheme
          .copyWith(
            displayLarge: baseTextTheme.displayLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            displayMedium: baseTextTheme.displayMedium?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            displaySmall: baseTextTheme.displaySmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            headlineLarge: baseTextTheme.headlineLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            headlineMedium: baseTextTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            headlineSmall: baseTextTheme.headlineSmall?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            titleLarge: baseTextTheme.titleLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            titleMedium: baseTextTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            titleSmall: baseTextTheme.titleSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 13),
            bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 12),
            bodySmall: baseTextTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: textMuted,
            ),
          )
          .apply(bodyColor: textLight, displayColor: textLight),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGold, size: 20),
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryGold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 12),
        hintStyle: const TextStyle(color: textMuted, fontSize: 12),
      ),
    );
  }

  static ThemeData get lightGoldTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primaryGold,
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        secondary: primaryGold,
        surface: lightSurfaceColor,
        background: lightBackground,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textDark,
        onBackground: textDark,
      ),
      textTheme: baseTextTheme
          .copyWith(
            displayLarge: baseTextTheme.displayLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            displayMedium: baseTextTheme.displayMedium?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            displaySmall: baseTextTheme.displaySmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            headlineLarge: baseTextTheme.headlineLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            headlineMedium: baseTextTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            headlineSmall: baseTextTheme.headlineSmall?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            titleLarge: baseTextTheme.titleLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            titleMedium: baseTextTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            titleSmall: baseTextTheme.titleSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 13),
            bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 12),
            bodySmall: baseTextTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: textMutedDark,
            ),
          )
          .apply(bodyColor: textDark, displayColor: textDark),
      dividerColor:
          Colors.black26, // Strong black lines for tables and dividers
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGold, size: 20),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceColor,
        elevation: 2,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black, // High contrast black on gold
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: lightSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFEBEBEB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFFEBEBEB),
          ), // Visible boundary for inputs
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryGold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMutedDark, fontSize: 12),
        hintStyle: const TextStyle(color: textMutedDark, fontSize: 12),
      ),
    );
  }
}
