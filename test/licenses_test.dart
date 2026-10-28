import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/about/licenses.dart';

void main() {
  List<String> packages(TargetPlatform platform, {bool web = false}) => [
    for (final l in bundledLicenses(platform, web: web)) ...l.packages,
  ];

  test('Android lists AndroidX and Kotlin', () {
    expect(
      packages(TargetPlatform.android),
      containsAll(['AndroidX', 'Kotlin Standard Library', 'libusb']),
    );
  });

  test('desktop lists libusb but no Android libraries', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(packages(platform), contains('libusb'));
      expect(packages(platform), isNot(contains('AndroidX')));
    }
  });

  test('web ships neither libusb nor Android libraries', () {
    final web = packages(TargetPlatform.android, web: true);
    expect(web, isNot(contains('libusb')));
    expect(web, isNot(contains('AndroidX')));
    expect(web, contains('Material Icons'));
  });

  test('all license assets exist', () {
    for (final platform in TargetPlatform.values) {
      for (final license in bundledLicenses(platform)) {
        expect(File('assets/licenses/${license.asset}').existsSync(), isTrue);
      }
    }
  });
}
