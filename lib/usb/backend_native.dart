import 'dart:io';

import 'package:unified_usb/native_usb.dart';
import 'package:unified_usb/unified_usb.dart';

import 'backend_android.dart';

/// Bulk transfers run on libusb's event thread, so an idle read never blocks
/// the UI isolate (the meter is polled continuously).
const _transferMode = UsbTransferMode.asyncEvents;

UsbBackend createUsbBackend() => Platform.isAndroid
    ? AndroidUsbBackend(transferMode: _transferMode)
    : NativeUsbBackend(transferMode: _transferMode);

/// Whether the app asks for USB permission by itself (Android), so no
/// "allow cable" button is needed.
bool usbPermissionsAutomatic(UsbBackend backend) =>
    backend is AndroidUsbBackend;

/// Shows the permission dialog for newly attached devices (Android only).
Future<void> requestMissingUsbPermissions(
  UsbBackend backend,
  List<UsbDeviceFilter> filters,
) async {
  if (backend is AndroidUsbBackend) {
    await backend.requestMissingPermissions(filters);
  }
}
