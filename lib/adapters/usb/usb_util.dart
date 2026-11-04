import 'package:unified_usb/unified_usb.dart';

/// Detaches an OS driver bound to [interfaceNumber] (Linux/Android
/// `ftdi_sio`, `cdc_acm`), which would otherwise make claiming the
/// interface fail. Returns whether a driver was detached.
Future<bool> detachKernelDriver(
  UsbBackend backend,
  UsbDevice device,
  int interfaceNumber,
) async {
  if (!backend.kernelDriverDetachSupported) return false;
  try {
    if (!await device.isKernelDriverActive(interfaceNumber)) return false;
    await device.detachKernelDriver(interfaceNumber);
    return true;
  } on UsbException {
    // Not permitted or not supported here; claiming will report the error.
    return false;
  }
}

/// Whether [a] and [b] describe the same physical device.
bool sameUsbDevice(UsbDeviceDescriptor a, UsbDeviceDescriptor b) =>
    a.vendorId == b.vendorId &&
    a.productId == b.productId &&
    a.serialNumber == b.serialNumber;
