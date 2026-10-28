import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A license shipped with the app that Flutter does not collect itself.
typedef BundledLicense = ({
  List<String> packages,

  /// Copyright line put before the license text, if the text has none.
  String? copyright,
  String asset,
});

/// Licenses of what the app ships on [platform] besides the Dart packages
/// and the Flutter engine (Flutter registers those itself).
List<BundledLicense> bundledLicenses(
  TargetPlatform platform, {
  bool web = false,
}) => [
  (
    packages: ['multimeter_viewer'],
    copyright: null,
    asset: 'multimeter_viewer-MIT.txt',
  ),
  // Memory protocol layout taken from these projects.
  (packages: ['dmm_util'], copyright: null, asset: 'dmm_util-MIT.txt'),
  (
    packages: ['fluke-28x-dmm-util'],
    copyright: null,
    asset: 'fluke-28x-dmm-util-MIT.txt',
  ),
  // Icon font Flutter bundles into every app.
  (
    packages: ['Material Icons'],
    copyright: 'Copyright Google LLC',
    asset: 'Apache-2.0.txt',
  ),
  // Shared library the native app loads (bundled on macOS and Android).
  if (!web)
    (packages: ['libusb'], copyright: null, asset: 'libusb-LGPL-2.1.txt'),
  if (!web && platform == TargetPlatform.android) ...[
    (
      packages: ['AndroidX'],
      copyright: 'Copyright The Android Open Source Project',
      asset: 'Apache-2.0.txt',
    ),
    (
      packages: ['Kotlin Standard Library'],
      copyright:
          'Copyright JetBrains s.r.o. and Kotlin Programming Language '
          'contributors',
      asset: 'Apache-2.0.txt',
    ),
  ],
];

/// Adds [bundledLicenses] of the running platform to Flutter's license
/// registry, which the licenses page shows.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final license in bundledLicenses(defaultTargetPlatform, web: kIsWeb)) {
      final text = await rootBundle.loadString(
        'assets/licenses/${license.asset}',
      );
      yield LicenseEntryWithLineBreaks(
        license.packages,
        license.copyright == null ? text : '${license.copyright}\n\n$text',
      );
    }
  });
}
