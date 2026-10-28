import 'package:unified_usb/unified_usb.dart';
import 'package:unified_usb/web_usb.dart';

UsbBackend createUsbBackend() => WebUsbBackend();

/// WebUSB devices must be picked by the user in the browser's chooser.
bool usbPermissionsAutomatic(UsbBackend backend) => false;

Future<void> requestMissingUsbPermissions(
  UsbBackend backend,
  List<UsbDeviceFilter> filters,
) async {}
