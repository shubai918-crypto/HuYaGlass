import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0A0A0F),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF6C5CE7),
      secondary: Color(0xFFA29BFE),
      surface: Color(0xFF1A1A2E),
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1A1A2E).withOpacity(0.8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
