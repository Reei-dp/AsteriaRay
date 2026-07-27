import 'package:flutter/material.dart';

enum AppLanguage {
  ru('ru'),
  uk('uk'),
  en('en');

  const AppLanguage(this.code);

  final String code;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.ru,
    );
  }

  /// Native label — always shown in its own language in the picker.
  String get nativeLabel => switch (this) {
        AppLanguage.ru => 'Русский',
        AppLanguage.uk => 'Українська',
        AppLanguage.en => 'English',
      };
}
