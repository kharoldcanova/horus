import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primaryColor = Color(0xFFFF6B35);
  static const _backgroundColor = Color(0xFF1A1A2E);
  static const _surfaceColor = Color(0xFF16213E);
  static const _successColor = Color(0xFF00E676);
  static const _errorColor = Color(0xFFFF1744);

  static ThemeData get rescueTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _successColor,
        surface: _surfaceColor,
        error: _errorColor,
      ),
      scaffoldBackgroundColor: _backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: Colors.white70,
        ),
      ),
    );
  }
}
