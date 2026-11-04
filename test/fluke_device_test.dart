import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/devices/fluke/fluke_device.dart';

void main() {
  test('names the supported meters', () {
    expect(FlukeDevice().supportedDevices, ['Fluke 287', 'Fluke 289']);
  });
}
