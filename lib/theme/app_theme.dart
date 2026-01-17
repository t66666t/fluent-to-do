import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF007AFF); // System Blue
  static const Color backgroundColor = Color(0xFFF2F2F7); // iOS System Grouped Background
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color successColor = Color(0xFF34C759); // System Green
  static const Color warningColor = Color(0xFFFF9500); // System Orange (used for in-progress sometimes)
  static const Color errorColor = Color(0xFFFF3B30); // System Red

  static const TextStyle titleLarge = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 34,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: 0.37,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.26,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 17,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: -0.41,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: -0.24,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: '.SF Pro Text', // Fallback
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: primaryColor,
        secondary: primaryColor,
        surface: cardColor,
      ),
      useMaterial3: true,
    );
  }
}
