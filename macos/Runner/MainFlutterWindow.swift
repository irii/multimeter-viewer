import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    useUnifiedTitleBar()
    let channel = registerWindowChannel(flutterViewController.engine.binaryMessenger)
    observeFullScreen(channel)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// The app's own bar replaces the grey title bar: the content reaches up
  /// to the top edge, and an empty unified toolbar makes the title bar as
  /// tall as the app bar (52 pt) with the window buttons centered in it.
  private func useUnifiedTitleBar() {
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    toolbar = NSToolbar(identifier: "MainToolbar")
    if #available(macOS 11.0, *) {
      toolbarStyle = .unified
      titlebarSeparatorStyle = .none
    }
  }

  /// In full screen the toolbar would show as a grey bar above the app bar
  /// and the window buttons are hidden: the toolbar goes away, and the app
  /// bars drop the room they leave for the buttons.
  private func observeFullScreen(_ channel: FlutterMethodChannel) {
    let center = NotificationCenter.default
    center.addObserver(
      forName: NSWindow.willEnterFullScreenNotification, object: self, queue: .main
    ) { [weak self] _ in
      self?.toolbar?.isVisible = false
      channel.invokeMethod("fullScreenChanged", arguments: true)
    }
    center.addObserver(
      forName: NSWindow.willExitFullScreenNotification, object: self, queue: .main
    ) { _ in
      channel.invokeMethod("fullScreenChanged", arguments: false)
    }
    // Shown again only after the transition: during it, AppKit keeps the
    // short title bar and the window buttons end up in the top left corner.
    center.addObserver(
      forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main
    ) { [weak self] _ in
      self?.toolbar?.isVisible = true
    }
  }

  @discardableResult
  private func registerWindowChannel(_ messenger: FlutterBinaryMessenger)
    -> FlutterMethodChannel
  {
    let channel = FlutterMethodChannel(
      name: "multimeter_viewer/window", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "setToolbarVisible":
        // Hidden in the compact view, which has no window buttons.
        self.toolbar?.isVisible = call.arguments as? Bool ?? true
        result(nil)
      case "titleBarDoubleClicked":
        self.performTitleBarDoubleClickAction()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return channel
  }

  /// What a double click on a title bar does, as set in the system settings
  /// (Desktop & Dock → "Double-click a window's title bar to").
  private func performTitleBarDoubleClickAction() {
    switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
    case "Minimize":
      performMiniaturize(nil)
    case "None":
      break
    default:
      performZoom(nil)
    }
  }
}
