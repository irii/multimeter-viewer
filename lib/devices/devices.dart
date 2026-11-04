/// The kinds of devices the app supports, sharing one adapter per transport.
/// A new kind of device is added here.
library;

import '../adapters/ble/ble_adapter.dart';
import '../adapters/usb/usb_adapter.dart';
import '../meter/meter_discovery.dart';
import 'fluke/fluke_device.dart';

/// The discovery of all devices, and the USB adapter for the serial monitor.
({MeterDiscovery discovery, UsbAdapter usb}) createMeterDiscovery() {
  final usb = UsbAdapter();
  final ble = BleAdapter.supported ? BleAdapter() : null;
  return (
    discovery: CompositeMeterDiscovery(
      [FlukeDevice(usb: usb, ble: ble)],
      onDispose: () {
        usb.dispose();
        ble?.dispose();
      },
    ),
    usb: usb,
  );
}
