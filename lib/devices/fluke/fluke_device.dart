import '../../adapters/ble/ble_adapter.dart';
import '../../adapters/ble/ble_serial.dart';
import '../../adapters/usb/usb_adapter.dart';
import '../../meter/adapter_meter_discovery.dart';
import '../../meter/meter_discovery.dart';
import '../../meter/model/meter_identity.dart';
import 'fluke_protocol.dart';

/// The IR USB cable (FTDI) and the IR adapter plugged in over USB (CDC). The
/// adapter's ESP32 reports a generic product name.
const _usbFilters = [
  UsbFilter(vendorId: 0x0403, driver: UsbSerialDriver.ftdi),
  UsbFilter(
    vendorId: 0x303A,
    driver: UsbSerialDriver.cdc,
    name: 'MMV-IR (USB)',
  ),
];

/// The Bluetooth IR adapter (`firmware/28x-ir-dongle`): an ESP32 that sends
/// the bytes it receives over Bluetooth LE to the meter's IR port and
/// notifies the bytes the meter answers. The meter protocol is the same as
/// over the USB cable.
const _bleFilters = [
  BleFilter(
    service: 'ca7c33cd-93df-40a9-83c7-4c9e4ee57a33',
    write: '077fee1f-2aa0-4b7a-8adb-8c1f7c51310b',
    notify: '9612beb0-f6ef-41ee-9a61-d7d51add4703',
  ),
];

/// Finds and connects Fluke 287 and 289 meters over the given adapters, which
/// other kinds of devices may share.
class FlukeDevice extends CompositeMeterDiscovery {
  FlukeDevice({UsbAdapter? usb, BleAdapter? ble})
    : super([
        if (usb != null)
          AdapterMeterDiscovery(
            adapter: usb,
            filters: _usbFilters,
            protocol: const FlukeProtocol(),
          ),
        if (ble != null)
          AdapterMeterDiscovery(
            adapter: ble,
            filters: _bleFilters,
            protocol: const FlukeProtocol(),
          ),
      ]);

  @override
  List<String> get supportedDevices => [
    for (final model in MeterModel.supported) model.label,
  ];
}
