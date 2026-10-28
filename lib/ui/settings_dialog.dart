import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../settings/settings_cubit.dart';

/// Language and theme selection.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();

    return AlertDialog(
      icon: const Icon(Icons.settings_outlined),
      title: Text(l10n.settings),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.language, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(
                  value: AppLanguage.system,
                  icon: const Icon(Icons.devices),
                  label: Text(l10n.languageSystem),
                ),
                ButtonSegment(
                  value: AppLanguage.de,
                  label: Text(l10n.languageGerman),
                ),
                ButtonSegment(
                  value: AppLanguage.en,
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {settings.language},
              onSelectionChanged: (s) => cubit.setLanguage(s.single),
            ),
            const SizedBox(height: 20),
            Text(l10n.theme, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto),
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode),
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode),
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => cubit.setThemeMode(s.single),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}
