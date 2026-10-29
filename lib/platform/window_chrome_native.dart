import 'dart:io';

import 'mac_window_chrome.dart';
import 'window_chrome.dart';

WindowChrome createPlatformWindowChrome() =>
    Platform.isMacOS ? MacWindowChrome() : const SystemWindowChrome();
