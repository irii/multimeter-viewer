import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/meter/model/model.dart';

void main() {
  const capabilities = MeterCapabilities(
    measurements: [
      MeterCapability(
        'V_DC',
        subFunctions: [
          MeterSubFunction('HOLD', MeterSubFunctionKind.mode, settable: true),
          MeterSubFunction('HERTZ', MeterSubFunctionKind.secondary),
        ],
      ),
      MeterCapability('OHMS', settable: true),
    ],
    features: [
      MeterCapability(
        MeterFeatures.properties,
        subFunctions: [
          MeterSubFunction(MeterFeatures.read, MeterSubFunctionKind.action),
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
        subFunction: MeterFeatures.read,
      ),
      isTrue,
    );
    expect(
      capabilities.hasFeature(
        MeterFeatures.properties,
        subFunction: MeterFeatures.write,
      ),
      isFalse,
    );
    expect(capabilities.hasFeature(MeterFeatures.memory), isFalse);
    expect(capabilities.hasFeature('V_DC'), isFalse);
  });

  test('capability and subfunction have their own flag', () {
    expect(capabilities.isSettable('OHMS'), isTrue);
    expect(capabilities.isSettable('V_DC'), isFalse);
    expect(capabilities.isSettable('V_DC', subFunction: 'HOLD'), isTrue);
    expect(capabilities.isSettable('V_DC', subFunction: 'HERTZ'), isFalse);
    expect(capabilities.isSettable('V_DC', subFunction: 'NOPE'), isFalse);
    expect(capabilities.isSettable('NOPE'), isFalse);
  });
}
