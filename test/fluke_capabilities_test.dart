import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/devices/fluke/fluke_capabilities.dart';
import 'package:multimeter_viewer/l10n/l10n.dart';
import 'package:multimeter_viewer/meter/model/model.dart';

import 'fakes.dart';

const _unknown = MeterIdentity(model: 'FLUKE 123', firmware: 'V1', serial: '1');

void main() {
  final full = flukeCapabilities(FakeLink.identity);

  test('the 287 lacks LoZ and LoΩ', () {
    final c287 = flukeCapabilities(fluke287Identity);
    expect(c287.measurement('V_AC_LOZ'), isNull);
    expect(c287.measurement('OHMS_LOW'), isNull);
    expect(c287.measurement('V_AC'), isNotNull);
    expect(c287.features, full.features);
  });

  test('the 289 and unknown models offer everything', () {
    expect(full.measurement('V_AC_LOZ'), isNotNull);
    expect(full.measurement('OHMS_LOW'), isNotNull);
    expect(flukeCapabilities(_unknown), full);
  });

  test('offers memory and properties', () {
    expect(
      full.hasFeature(MeterFeatures.memory, subFunction: MeterFeatures.read),
      isTrue,
    );
    expect(
      full.hasFeature(
        MeterFeatures.properties,
        subFunction: MeterFeatures.write,
      ),
      isTrue,
    );
  });

  test('only the backlight can be set', () {
    for (final capability in [...full.measurements, ...full.features]) {
      expect(capability.settable, isFalse, reason: capability.id);
      for (final sub in capability.subFunctions) {
        expect(
          sub.settable,
          capability.id == MeterFeatures.backlight &&
              sub.id == MeterFeatures.press,
          reason: '${capability.id}/${sub.id}',
        );
      }
    }
  });

  test('every subfunction of a mode has a label', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final measurement in full.measurements) {
      expect(l10n.primaryFunction(measurement.id), isNotEmpty);
      expect(measurement.subFunctions, isNotEmpty, reason: measurement.id);
      for (final sub in measurement.subFunctions) {
        final label = switch (sub.kind) {
          MeterSubFunctionKind.secondary => l10n.secondaryFunction(sub.id),
          _ => l10n.mode(sub.id),
        };
        expect(label, isNotNull, reason: sub.id);
      }
    }
  });
}
