import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Persists [AppSettings] between app starts.
abstract interface class SettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// [SettingsStore] backed by `shared_preferences` (user defaults, registry,
/// a JSON file or `localStorage`, depending on the platform).
class SharedPreferencesSettingsStore implements SettingsStore {
  static const _languageKey = 'language';
  static const _themeKey = 'themeMode';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<AppSettings> load() async {
    try {
      final language = await _prefs.getString(_languageKey);
      final theme = await _prefs.getString(_themeKey);
      return AppSettings(
        language:
            AppLanguage.values.asNameMap()[language] ?? AppLanguage.system,
        themeMode: ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system,
      );
    } catch (_) {
      // Storage unavailable (e.g. blocked in a private browser window).
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await _prefs.setString(_languageKey, settings.language.name);
      await _prefs.setString(_themeKey, settings.themeMode.name);
    } catch (_) {
      // Not persisted; the setting still applies for this session.
    }
  }
}

/// Non-persistent [SettingsStore], e.g. for tests.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.settings = const AppSettings()]);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;
}
