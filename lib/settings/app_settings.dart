import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// UI language; [system] follows the operating system.
enum AppLanguage {
  system(null),
  de(Locale('de')),
  en(Locale('en'));

  const AppLanguage(this.locale);

  /// `null` lets Flutter pick from the system locales.
  final Locale? locale;
}

final class AppSettings extends Equatable {
  const AppSettings({
    this.language = AppLanguage.system,
    this.themeMode = ThemeMode.system,
  });

  final AppLanguage language;
  final ThemeMode themeMode;

  AppSettings copyWith({AppLanguage? language, ThemeMode? themeMode}) =>
      AppSettings(
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  List<Object?> get props => [language, themeMode];
}
