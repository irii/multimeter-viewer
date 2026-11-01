/// Minimal USB CDC-ACM serial driver on top of `unified_usb`, for the
/// Bluetooth IR adapter while it is plugged in over USB
/// (`firmware/ir-ble-adapter`): it passes the bytes through to the meter's
/// IR port at the meter's 115200 baud, so no line settings are sent.
library;

import 'dart:async';

import 'package:unified_usb/unified_usb.dart';

import '../fluke/fluke_client.dart';
import 'usb_util.dart';

/// Espressif: the adapter's ESP32 shows up with its own USB controller.
const int espressifVendorId = 0x303A;

/// USB class of the CDC data interface that carries the bytes.
const int _cdcDataClass = 0x0A;

class CdcSerial implements SerialChannel {
  CdcSerial._(
    this._backend,
    this._device,
    this._interfaceNumber,
    this._endpointIn,
    this._endpointOut,
    this._maxPacketSize,
    this._kernelDriverDetached,
  ) {
    _removedSub = _backend.onDeviceDisconnected.listen((d) {
      if (d == _device || sameUsbDevice(d.descriptor, _device.descriptor)) {
        _removed.add(null);
      }
    });
  }

  final UsbBackend _backend;
  final UsbDevice _device;
  final int _interfaceNumber;
  final int _endpointIn;
  final int _endpointOut;
  final int _maxPacketSize;
  final bool _kernelDriverDetached;
  final _removed = StreamController<void>.broadcast();
  late final StreamSubscription<UsbDevice> _removedSub;

  /// Opens the CDC data interface of [device].
  static Future<CdcSerial> open(UsbBackend backend, UsbDevice device) async {
    await device.open();
    try {
      final configs = device.descriptor.configurations;
      try {
        await device.selectConfiguration(
          configs.isEmpty ? 1 : configs.first.configurationValue,
        );
      } on UsbException {
        // Already configured (or the OS does not allow changing it).
      }

      UsbInterfaceDescriptor? dataInterface;
      for (final iface
          in configs.isEmpty ? const [] : configs.first.interfaces) {
        if (iface.alternates.any((a) => a.interfaceClass == _cdcDataClass)) {
          dataInterface = iface;
          break;
        }
      }
      if (dataInterface == null) {
        throw UsbException('No CDC data interface on the device');
      }
      final endpoints = dataInterface.alternates
          .firstWhere((a) => a.interfaceClass == _cdcDataClass)
          .endpoints;
      UsbEndpointDescriptor bulk(UsbDirection direction) =>
          endpoints.firstWhere(
            (e) => e.type == UsbEndpointType.bulk && e.direction == direction,
            orElse: () => throw UsbException(
              'CDC data interface without bulk '
              '${direction.name} endpoint',
            ),
          );
      final epIn = bulk(UsbDirection.inDirection);
      final epOut = bulk(UsbDirection.outDirection);

      final interfaceNumber = dataInterface.interfaceNumber;
      final detached = await detachKernelDriver(
        backend,
        device,
        interfaceNumber,
      );
      await device.claimInterface(interfaceNumber);
      return CdcSerial._(
        backend,
        device,
        interfaceNumber,
        epIn.endpointNumber,
        epOut.endpointNumber,
        epIn.maxPacketSize,
        detached,
      );
    } catch (_) {
      await device.close();
      rethrow;
    }
  }

  @override
  Stream<void> get onRemoved => _removed.stream;

  @override
  Future<void> write(List<int> data) async {
    final result = await _device.transferOut(_endpointOut, data);
    if (result.status != UsbTransferStatus.ok ||
        result.bytesWritten != data.length) {
      throw UsbException(
        'Write failed: ${result.status.name} '
        '(${result.bytesWritten}/${data.length} bytes)',
      );
    }
  }

  @override
  Future<List<int>> read() async {
    final result = await _device.transferIn(_endpointIn, _maxPacketSize * 64);
    if (result.status != UsbTransferStatus.ok &&
        result.status != UsbTransferStatus.timeout) {
      throw UsbException('Read failed: ${result.status.name}');
    }
    return result.data;
  }

  @override
  Future<void> close() async {
    await _removedSub.cancel();
    await _removed.close();
    try {
      await _device.releaseInterface(_interfaceNumber);
    } on UsbException {
      // Device may already be gone.
    }
    if (_kernelDriverDetached) {
      try {
        // Give the adapter back to the OS (e.g. as /dev/ttyACM0).
        await _device.attachKernelDriver(_interfaceNumber);
      } on UsbException {
        // Device gone or driver no longer available.
      }
    }
    try {
      await _device.close();
    } on UsbException {
      // Device may already be gone.
    }
  }
}
