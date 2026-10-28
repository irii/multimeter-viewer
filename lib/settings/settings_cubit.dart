import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_settings.dart';
import 'settings_store.dart';

export 'app_settings.dart';

/// Language and theme of the app; changes are saved to [SettingsStore].
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._store, [super.initial = const AppSettings()]);

  final SettingsStore _store;

  void setLanguage(AppLanguage language) =>
      _update(state.copyWith(language: language));

  void setThemeMode(ThemeMode themeMode) =>
      _update(state.copyWith(themeMode: themeMode));

  void _update(AppSettings settings) {
    if (settings == state) return;
    emit(settings);
    _store.save(settings);
  }
}
