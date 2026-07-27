import 'package:flutter/material.dart';

abstract final class AsteriaThemes {
  static const _radius = 16.0;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D9FF),
          secondary: Color(0xFF00D9FF),
          surface: Color(0xFF000000),
          error: Color(0xFFCF6679),
          onPrimary: Color(0xFF000000),
          onSecondary: Color(0xFF000000),
          onSurface: Color(0xFFFFFFFF),
          onError: Color(0xFF000000),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0A0A0A),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00D9FF),
          foregroundColor: Color(0xFF000000),
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A8CC),
          primary: const Color(0xFF009BB8),
          secondary: const Color(0xFF009BB8),
          surface: const Color(0xFFF7F8FA),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0F2F5),
          foregroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF009BB8),
          foregroundColor: Colors.white,
        ),
      );
}
