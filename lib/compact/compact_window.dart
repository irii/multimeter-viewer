import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/window_chrome.dart';

/// Whether the app runs as a desktop app (macOS, Windows, Linux).
bool get isDesktopPlatform =>
    !kIsWeb &&
    const {
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);

/// The platform's compact window: a desktop panel or Android's
/// picture-in-picture window; `null` where there is none (web, iOS).
CompactWindow? createCompactWindow() {
  if (isDesktopPlatform) return WindowManagerCompactWindow();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidPipWindow();
  }
  return null;
}

/// Native window operations needed for the compact view.
abstract interface class CompactWindow {
  /// Shrinks the window to a small, always-on-top panel.
  Future<void> enterCompact();

  /// Restores the window from before [enterCompact].
  Future<void> exitCompact();

  /// Whether the panel shows its own buttons and can be moved and resized
  /// by dragging it. Android's picture-in-picture window takes no taps.
  bool get hasControls;

  Future<void> setAlwaysOnTop(bool alwaysOnTop);

  /// Fires when the system ends the compact view, e.g. when the user
  /// expands or closes the picture-in-picture window.
  Stream<void> get onClosedBySystem;
}

/// [CompactWindow] backed by `window_manager`.
class WindowManagerCompactWindow implements CompactWindow {
  static const compactSize = Size(360, 170);
  static const compactMinimumSize = Size(220, 110);
  static const normalMinimumSize = Size(400, 360);

  Rect? _normalBounds;

  @override
  Future<void> enterCompact() async {
    _normalBounds = await windowManager.getBounds();
    await WindowChrome.instance.hideTitleBar();
    await windowManager.setMinimumSize(compactMinimumSize);
    await windowManager.setSize(compactSize);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.focus();
  }

  @override
  Future<void> exitCompact() async {
    await windowManager.setAlwaysOnTop(false);
    await WindowChrome.instance.restoreTitleBar();
    await windowManager.setMinimumSize(normalMinimumSize);
    final bounds = _normalBounds;
    if (bounds != null) await windowManager.setBounds(bounds);
    _normalBounds = null;
  }

  @override
  bool get hasControls => true;

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) =>
      windowManager.setAlwaysOnTop(alwaysOnTop);

  @override
  Stream<void> get onClosedBySystem => const Stream.empty();
}

/// [CompactWindow] using Android's picture-in-picture mode (see
/// `MainActivity.kt`). The window always stays on top.
class AndroidPipWindow implements CompactWindow {
  AndroidPipWindow() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closed') _closed.add(null);
    });
  }

  static const _channel = MethodChannel('multimeter_viewer/compact');
  final _closed = StreamController<void>.broadcast();

  @override
  Future<void> enterCompact() async {
    if (await _channel.invokeMethod<bool>('enter') != true) {
      throw UnsupportedError('Picture-in-picture is not available');
    }
  }

  @override
  Future<void> exitCompact() => _channel.invokeMethod<void>('exit');

  @override
  bool get hasControls => false;

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {}

  @override
  Stream<void> get onClosedBySystem => _closed.stream;
}
