/// Minimal FTDI (FT232R) USB-serial driver on top of `unified_usb`, enough to
/// talk to the meter's IR USB cable at 115200 8N1.
library;

import 'dart:async';

import 'package:unified_usb/unified_usb.dart';

import '../fluke/fluke_client.dart';

const int ftdiVendorId = 0x0403;

// FTDI vendor requests (see libftdi / AN232B-04).
const int _sioReset = 0x00;
const int _sioSetModemCtrl = 0x01;
const int _sioSetFlowCtrl = 0x02;
const int _sioSetBaudRate = 0x03;
const int _sioSetData = 0x04;
const int _sioSetLatencyTimer = 0x09;

const int _resetSio = 0;
const int _purgeRx = 1;
const int _purgeTx = 2;

/// 3 MHz / 26 = 115384 baud (0.16 % off 115200).
const int _baud115200Divisor = 0x001A;

/// 8 data bits, no parity, 1 stop bit.
const int _data8N1 = 0x0008;

/// DTR and RTS high (bits 0/1 = value, bits 8/9 = enable).
const int _dtrRtsOn = 0x0303;

/// Number of modem-status bytes the FTDI chip prepends to every IN packet.
const int _statusBytesPerPacket = 2;

class FtdiSerial implements SerialChannel {
  FtdiSerial._(
    this._backend,
    this._device,
    this._interfaceNumber,
    this._endpointIn,
    this._endpointOut,
    this._maxPacketSize,
    this._kernelDriverDetached,
  ) {
    _removedSub = _backend.onDeviceDisconnected.listen((d) {
      if (d == _device || _sameDevice(d.descriptor, _device.descriptor)) {
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

  /// Whether [open] detached an OS driver, to re-attach it on [close].
  final bool _kernelDriverDetached;
  final _removed = StreamController<void>.broadcast();
  late final StreamSubscription<UsbDevice> _removedSub;

  /// Opens the FTDI cable [device] and configures it for 115200 8N1.
  static Future<FtdiSerial> open(UsbBackend backend, UsbDevice device) async {
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

      final iface = configs.isEmpty || configs.first.interfaces.isEmpty
          ? null
          : configs.first.interfaces.first;
      final interfaceNumber = iface?.interfaceNumber ?? 0;
      final endpoints = iface == null || iface.alternates.isEmpty
          ? const <UsbEndpointDescriptor>[]
          : iface.alternates.first.endpoints;
      UsbEndpointDescriptor? findBulk(UsbDirection direction) {
        for (final e in endpoints) {
          if (e.type == UsbEndpointType.bulk && e.direction == direction) {
            return e;
          }
        }
        return null;
      }

      final epIn = findBulk(UsbDirection.inDirection);
      final epOut = findBulk(UsbDirection.outDirection);

      final detached = await _detachKernelDriver(
        backend,
        device,
        interfaceNumber,
      );
      await device.claimInterface(interfaceNumber);

      final serial = FtdiSerial._(
        backend,
        device,
        interfaceNumber,
        epIn?.endpointNumber ?? 1,
        epOut?.endpointNumber ?? 2,
        epIn?.maxPacketSize ?? 64,
        detached,
      );
      await serial._configure();
      return serial;
    } catch (_) {
      await device.close();
      rethrow;
    }
  }

  UsbDeviceDescriptor get descriptor => _device.descriptor;

  @override
  Stream<void> get onRemoved => _removed.stream;

  Future<void> _configure() async {
    await _control(_sioReset, _resetSio);
    await _control(_sioSetModemCtrl, _dtrRtsOn);
    await _control(_sioSetFlowCtrl, 0);
    await _control(_sioSetBaudRate, _baud115200Divisor);
    await _control(_sioSetData, _data8N1);
    await _control(_sioSetLatencyTimer, 16);
    await purge();
  }

  /// Drops any bytes pending in the chip's RX and TX buffers.
  Future<void> purge() async {
    await _control(_sioReset, _purgeRx);
    await _control(_sioReset, _purgeTx);
  }

  Future<void> _control(int request, int value) async {
    final result = await _device.controlTransferOut(
      UsbControlSetup(
        requestType: UsbControlTransferType.vendor,
        recipient: UsbRecipient.device,
        request: request,
        value: value,
        index: 0,
      ),
      const [],
    );
    if (result.status != UsbTransferStatus.ok) {
      throw UsbException(
        'FTDI control request 0x${request.toRadixString(16)} failed: '
        '${result.status.name}',
      );
    }
  }

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
    return stripModemStatus(result.data, _maxPacketSize);
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
        // Give the cable back to the OS (e.g. as /dev/ttyUSB0).
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

  /// Detaches an OS driver bound to the cable (Linux/Android `ftdi_sio`),
  /// which would otherwise make claiming the interface fail. Returns whether
  /// a driver was detached.
  static Future<bool> _detachKernelDriver(
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

  static bool _sameDevice(UsbDeviceDescriptor a, UsbDeviceDescriptor b) =>
      a.vendorId == b.vendorId &&
      a.productId == b.productId &&
      a.serialNumber == b.serialNumber;
}

/// Removes the 2 modem-status bytes the FTDI chip puts at the start of each
/// [maxPacketSize] chunk of a bulk IN transfer.
List<int> stripModemStatus(List<int> data, int maxPacketSize) {
  final payload = <int>[];
  for (var offset = 0; offset < data.length; offset += maxPacketSize) {
    final end = offset + maxPacketSize < data.length
        ? offset + maxPacketSize
        : data.length;
    if (end - offset > _statusBytesPerPacket) {
      payload.addAll(data.sublist(offset + _statusBytesPerPacket, end));
    }
  }
  return payload;
}
