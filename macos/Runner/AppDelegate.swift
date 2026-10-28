import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var menuChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      menuChannel = FlutterMethodChannel(
        name: "multimeter_viewer/menu", binaryMessenger: controller.engine.binaryMessenger)
      routeAppMenuToFlutter()
    }
  }

  /// "About" and "Settings…" of the app menu open the app's own pages
  /// instead of the standard about panel.
  private func routeAppMenuToFlutter() {
    guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
    for item in appMenu.items {
      if item.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)) {
        item.target = self
        item.action = #selector(showAbout(_:))
      } else if item.keyEquivalent == "," {
        item.target = self
        item.action = #selector(showSettings(_:))
      }
    }
  }

  @objc private func showAbout(_ sender: Any?) {
    menuChannel?.invokeMethod("about", arguments: nil)
  }

  @objc private func showSettings(_ sender: Any?) {
    menuChannel?.invokeMethod("settings", arguments: nil)
  }
}
