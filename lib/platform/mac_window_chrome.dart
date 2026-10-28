import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'window_chrome.dart';

/// macOS: the title bar is transparent and the app bars sit under it next to
/// the native window buttons (see `MainFlutterWindow.swift`).
class MacWindowChrome extends WindowChrome {
  const MacWindowChrome();

  static const _channel = MethodChannel('multimeter_viewer/window');

  @override
  bool get drawsTitleBar => true;

  /// Height of the title bar with its unified toolbar, so the window
  /// buttons are centered in the app bars.
  @override
  double get titleBarHeight => 52;

  /// Close, minimize and zoom buttons.
  @override
  EdgeInsets get titleBarPadding => const EdgeInsets.only(left: 72);

  @override
  Future<void> startDragging() => windowManager.startDragging();

  /// Zooms or minimizes, as set in the system settings.
  @override
  Future<void> titleBarDoubleClicked() =>
      _channel.invokeMethod<void>('titleBarDoubleClicked');

  @override
  Future<void> hideTitleBar() async {
    // The toolbar gives the title bar its height; the panel has no use for it.
    await _channel.invokeMethod<void>('setToolbarVisible', false);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  @override
  Future<void> restoreTitleBar() async {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await _channel.invokeMethod<void>('setToolbarVisible', true);
  }
}
