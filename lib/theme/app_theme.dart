import 'package:flutter/material.dart';

enum AppTheme {
  dark('dark'),
  light('light');

  const AppTheme(this.storageKey);

  final String storageKey;

  ThemeMode get themeMode =>
      this == AppTheme.light ? ThemeMode.light : ThemeMode.dark;

  static AppTheme fromStorage(String? code) {
    return code == light.storageKey ? AppTheme.light : AppTheme.dark;
  }
}
