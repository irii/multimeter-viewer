/// Selects the [WindowChrome] implementations available on native
/// platforms or in the browser.
library;

export 'window_chrome_native.dart'
    if (dart.library.js_interop) 'window_chrome_web.dart';
