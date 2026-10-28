import 'package:flutter/services.dart';

/// Entries of the native app menu that open pages of the app (macOS: "About"
/// and "Settings…", see `AppDelegate.swift`).
enum AppMenuCommand { about, settings }

abstract final class AppMenu {
  static const _channel = MethodChannel('multimeter_viewer/menu');

  /// Calls [onCommand] when the user picks one of the entries. Platforms
  /// without such a menu never call it.
  static void listen(void Function(AppMenuCommand command) onCommand) =>
      _channel.setMethodCallHandler((call) async {
        if (AppMenuCommand.values.asNameMap()[call.method] case final c?) {
          onCommand(c);
        }
      });

  static void stopListening() => _channel.setMethodCallHandler(null);
}
