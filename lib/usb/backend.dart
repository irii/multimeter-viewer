/// Selects the libusb backend on native platforms and WebUSB in the browser.
library;

export 'backend_native.dart' if (dart.library.js_interop) 'backend_web.dart';
