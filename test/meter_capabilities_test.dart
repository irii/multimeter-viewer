import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/meter/model/model.dart';

void main() {
  const capabilities = MeterCapabilities(
    measurements: [
      MeterCapability(
        'V_DC',
        subCapabilities: [
          MeterSubCapability(
            'HOLD',
            MeterControl.toggle,
            source: MeterStateSource.mode,
            settable: true,
          ),
          MeterSubCapability(
            'HERTZ',
            MeterControl.toggle,
            source: MeterStateSource.secondaryFunction,
          ),
        ],
      ),
      MeterCapability('OHMS', settable: true),
    ],
    features: [
      MeterCapability(
        MeterFeatures.properties,
        subCapabilities: [
          MeterSubCapability(MeterFeatures.read, MeterControl.none),
        ],
      ),
    ],
  );

  test('finds a measurement by its ID', () {
    expect(capabilities.measurement('OHMS')?.id, 'OHMS');
    expect(capabilities.measurement('NOPE'), isNull);
    expect(
      capabilities.measurement(MeterFeatures.properties),
      isNull,
      reason: 'features are separate',
    );
  });

  test('knows features and their subfunctions', () {
    expect(capabilities.hasFeature(MeterFeatures.properties), isTrue);
    expect(
      capabilities.hasFeature(
        MeterFeatures.properties,
        sub: MeterFeatures.read,
      ),
      isTrue,
    );
    expect(
      capabilities.hasFeature(
        MeterFeatures.properties,
        sub: MeterFeatures.write,
      ),
      isFalse,
    );
    expect(capabilities.hasFeature(MeterFeatures.memory), isFalse);
    expect(capabilities.hasFeature('V_DC'), isFalse);
  });

  test('capability and subfunction have their own flag', () {
    expect(capabilities.isSettable('OHMS'), isTrue);
    expect(capabilities.isSettable('V_DC'), isFalse);
    expect(capabilities.isSettable('V_DC', sub: 'HOLD'), isTrue);
    expect(capabilities.isSettable('V_DC', sub: 'HERTZ'), isFalse);
    expect(capabilities.isSettable('V_DC', sub: 'NOPE'), isFalse);
    expect(capabilities.isSettable('NOPE'), isFalse);
  });
}
