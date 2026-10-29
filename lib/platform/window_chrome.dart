import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show EdgeInsets, kToolbarHeight;
import 'package:window_manager/window_manager.dart';

import 'window_chrome_factory.dart';

/// How the app window's title bar is drawn on the desktop: by the system, or
/// by the app's own bars next to the native window buttons.
///
/// [instance] is set once at startup with [WindowChrome.forPlatform]; until
/// then (and in tests) the system draws the title bar.
abstract class WindowChrome {
  const WindowChrome();

  /// The implementation of the running platform.
  static WindowChrome instance = const SystemWindowChrome();

  /// Picks the implementation for the platform: chosen at compile time for
  /// the web, by the operating system at runtime elsewhere.
  factory WindowChrome.forPlatform() => createPlatformWindowChrome();

  /// Whether the app bars act as the title bar (no system title bar).
  bool get drawsTitleBar;

  /// Height of the app bars when they act as the title bar.
  double get titleBarHeight;

  /// Room the app bars leave for the native window buttons.
  EdgeInsets get titleBarPadding;

  /// Whether the window is in full screen, where the window buttons are
  /// hidden and the app bars need no [titleBarPadding].
  ValueListenable<bool> get fullScreen => _notFullScreen;

  static final _notFullScreen = ValueNotifier(false);

  /// Moves the window with the pointer (drag on the title bar).
  Future<void> startDragging();

  /// Zooms, maximizes or minimizes the window like a double click on a
  /// native title bar.
  Future<void> titleBarDoubleClicked();

  /// Hides the title bar and the window buttons for the compact panel.
  Future<void> hideTitleBar();

  /// Restores the title bar after [hideTitleBar].
  Future<void> restoreTitleBar();
}

/// The system draws the title bar (Windows, Linux; mobile and web have
/// none to change).
class SystemWindowChrome extends WindowChrome {
  const SystemWindowChrome();

  @override
  bool get drawsTitleBar => false;

  @override
  double get titleBarHeight => kToolbarHeight;

  @override
  EdgeInsets get titleBarPadding => EdgeInsets.zero;

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> titleBarDoubleClicked() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> hideTitleBar() => windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  @override
  Future<void> restoreTitleBar() =>
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
}
