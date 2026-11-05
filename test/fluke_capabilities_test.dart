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

  test('the backlight is a button', () {
    expect(
      full.feature('backlight')?.sub('press'),
      const MeterSubCapability('press', MeterControl.button, settable: true),
    );
  });

  test('offers memory and properties', () {
    expect(
      full.hasFeature(MeterFeatures.memory, sub: MeterFeatures.read),
      isTrue,
    );
    expect(
      full.hasFeature(MeterFeatures.properties, sub: MeterFeatures.write),
      isTrue,
    );
  });

  test('only the backlight can be set', () {
    for (final capability in [...full.measurements, ...full.features]) {
      expect(capability.settable, isFalse, reason: capability.id);
      for (final sub in capability.subCapabilities) {
        expect(
          sub.settable,
          capability.id == 'backlight' && sub.id == 'press',
          reason: '${capability.id}/${sub.id}',
        );
      }
    }
  });

  test('every subfunction of a mode has a label', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final measurement in full.measurements) {
      expect(l10n.primaryFunction(measurement.id), isNotEmpty);
      expect(measurement.subCapabilities, isNotEmpty, reason: measurement.id);
      for (final sub in measurement.subCapabilities) {
        expect(sub.control, MeterControl.toggle, reason: sub.id);
        expect(sub.source, isNot(MeterStateSource.none), reason: sub.id);
        if (sub.source == MeterStateSource.secondaryFunction) {
          expect(l10n.secondaryFunction(sub.id), isNotNull, reason: sub.id);
        }
      }
    }
  });
}
