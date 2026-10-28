import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'about/licenses.dart';
import 'app.dart';
import 'compact/compact_window.dart';
import 'platform/window_chrome.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicenses();
  WindowChrome.instance = WindowChrome.forPlatform();
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(
      WindowManagerCompactWindow.normalMinimumSize,
    );
  }
  // Load before the first frame so the app starts in the saved language and
  // theme without flickering.
  final settingsStore = SharedPreferencesSettingsStore();
  final settings = await settingsStore.load();
  runApp(
    MultimeterViewerApp(
      settingsStore: settingsStore,
      initialSettings: settings,
    ),
  );
}
