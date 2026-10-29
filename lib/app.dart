import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'about/app_info.dart';
import 'bloc/meter_bloc.dart';
import 'bloc/time_base_cubit.dart';
import 'compact/compact_mode_cubit.dart';
import 'compact/compact_window.dart';
import 'fluke/meter_discovery.dart';
import 'l10n/l10n.dart';
import 'platform/app_menu.dart';
import 'platform/window_chrome.dart';
import 'recording/recording_bloc.dart';
import 'recording/recording_files.dart';
import 'recording/viewer_bloc.dart';
import 'router.dart';
import 'ui/settings_dialog.dart';
import 'settings/settings_cubit.dart';
import 'settings/settings_store.dart';
import 'usb/usb_meter_discovery.dart';

class MultimeterViewerApp extends StatefulWidget {
  const MultimeterViewerApp({
    super.key,
    this.discovery,
    this.pickRecordingFile,
    this.compactWindow,
    this.settingsStore,
    this.initialSettings = const AppSettings(),
  });

  /// Overrides the USB discovery/connection, e.g. in tests.
  final MeterDiscovery? discovery;

  /// Overrides the file dialog for opening recordings, e.g. in tests.
  final Future<PickedTextFile?> Function()? pickRecordingFile;

  /// Overrides the native window control for the compact view, e.g. in
  /// tests. Defaults to [createCompactWindow].
  final CompactWindow? compactWindow;

  /// Where language and theme are saved; `shared_preferences` by default.
  final SettingsStore? settingsStore;

  /// Settings to start with (loaded from [settingsStore] before `runApp`).
  final AppSettings initialSettings;

  @override
  State<MultimeterViewerApp> createState() => _MultimeterViewerAppState();
}

class _MultimeterViewerAppState extends State<MultimeterViewerApp> {
  late final MeterDiscovery _discovery =
      widget.discovery ?? UsbMeterDiscovery();
  late final MeterBloc _meterBloc = MeterBloc(connector: _discovery.connect);
  late final RecordingBloc _recordingBloc = RecordingBloc(
    meterStates: _meterBloc.stream,
  );
  late final RecordingViewerBloc _viewerBloc = RecordingViewerBloc(
    pickFile: widget.pickRecordingFile,
  );
  late final CompactModeCubit _compactCubit = CompactModeCubit(
    widget.compactWindow ?? createCompactWindow(),
  );
  late final SettingsCubit _settingsCubit = SettingsCubit(
    widget.settingsStore ?? SharedPreferencesSettingsStore(),
    widget.initialSettings,
  );
  late final GoRouter _router = createRouter(_meterBloc);
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    AppMenu.listen(_onMenuCommand);
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  /// Closes the meter connection and the USB backend before the app quits
  /// (desktop: last window closed, Cmd+Q). Without this, quitting hangs
  /// until libusb's event isolate wakes up by itself.
  Future<AppExitResponse> _onExitRequested() async {
    try {
      await _meterBloc.close().timeout(const Duration(seconds: 1));
    } catch (_) {
      // Quit anyway.
    }
    _discovery.dispose();
    // The backend stops its event isolate asynchronously and offers nothing
    // to await; this is enough for it once no transfer is in flight.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return AppExitResponse.exit;
  }

  /// "About" and "Settings…" from the native app menu (macOS).
  void _onMenuCommand(AppMenuCommand command) {
    // The compact panel is too small for pages and dialogs.
    if (_compactCubit.state.active) return;
    switch (command) {
      case AppMenuCommand.about:
        if (_router.state.matchedLocation != Routes.about) {
          _router.push(Routes.about);
        }
      case AppMenuCommand.settings:
        final context = _router.routerDelegate.navigatorKey.currentContext;
        if (context != null) {
          showDialog<void>(
            context: context,
            builder: (_) => const SettingsDialog(),
          );
        }
    }
  }

  @override
  void dispose() {
    AppMenu.stopListening();
    _lifecycle.dispose();
    _router.dispose();
    _settingsCubit.close();
    _compactCubit.close();
    _viewerBloc.close();
    _recordingBloc.close();
    _meterBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFF57C00); // orange of the app icon
    return RepositoryProvider.value(
      value: _discovery,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _meterBloc),
          BlocProvider.value(value: _recordingBloc),
          BlocProvider.value(value: _viewerBloc),
          BlocProvider(create: (_) => TimeBaseCubit()),
          BlocProvider.value(value: _compactCubit),
          BlocProvider.value(value: _settingsCubit),
        ],
        // Give the window its normal size back when the meter goes away
        // while the compact panel is shown.
        child: BlocListener<MeterBloc, MeterState>(
          listenWhen: (previous, current) =>
              previous.isConnected && !current.isConnected,
          listener: (context, state) => _compactCubit.exit(),
          child: BlocBuilder<SettingsCubit, AppSettings>(
            builder: (context, settings) => MaterialApp.router(
              title: AppInfo.name,
              debugShowCheckedModeBanner: false,
              locale: settings.language.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              localeListResolutionCallback: resolveLocale,
              themeMode: settings.themeMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seed),
                appBarTheme: _appBarTheme,
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                ),
                appBarTheme: _appBarTheme,
                useMaterial3: true,
              ),
              routerConfig: _router,
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks German or English from the system's preferred languages; anything
/// else falls back to English.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

/// App bars as tall as the title bar where they act as one (see
/// [WindowChrome]).
AppBarTheme? get _appBarTheme {
  final chrome = WindowChrome.instance;
  return chrome.drawsTitleBar
      ? AppBarTheme(toolbarHeight: chrome.titleBarHeight)
      : null;
}
