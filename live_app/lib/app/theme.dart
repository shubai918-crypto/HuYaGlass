import 'package:flutter/material.dart';

/// 深色主题（参考 dtv_mobile 的沉浸式暗色风格）
class AppTheme {
  static const _bgColor = Color(0xFF0A0A0F);
  static const _surfaceColor = Color(0xFF1A1A2E);
  static const _primaryColor = Color(0xFF6C5CE7);
  static const _secondaryColor = Color(0xFFA29BFE);
  static const _accentColor = Color(0xFF00D2FF);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bgColor,
    colorScheme: const ColorScheme.dark(
      primary: _primaryColor,
      secondary: _secondaryColor,
      surface: _surfaceColor,
      onSurface: Colors.white,
      error: Color(0xFFFF6B6B),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardTheme(
      color: _surfaceColor.withOpacity(0.8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
    ),
  );
}
