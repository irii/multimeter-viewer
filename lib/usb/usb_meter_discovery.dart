import 'dart:async';

import 'package:unified_usb/unified_usb.dart';

import '../fluke/fluke_client.dart';
import '../fluke/meter_discovery.dart';
import '../fluke/releasing_link.dart';
import 'backend.dart';
import 'cdc_serial.dart';
import 'ftdi_serial.dart';

/// The IR USB cable (FTDI) and the Bluetooth IR adapter plugged in over
/// USB (Espressif, CDC).
const _filters = [
  UsbDeviceFilter(vendorId: ftdiVendorId),
  UsbDeviceFilter(vendorId: espressifVendorId),
];

/// Shown for the IR adapter in USB mode.
const irAdapterUsbName = 'MMV-IR (USB)';

bool _isMeterCable(UsbDevice d) =>
    _filters.any((f) => f.vendorId == d.descriptor.vendorId);

/// Opens the serial driver that fits [device].
Future<SerialChannel> _openSerial(UsbBackend backend, UsbDevice device) =>
    device.descriptor.vendorId == espressifVendorId
    ? CdcSerial.open(backend, device)
    : FtdiSerial.open(backend, device);

/// [MeterDiscovery] over USB via `unified_usb`: FTDI cables and the IR
/// adapter in USB mode.
///
/// Scans and connects run one at a time, and a cable with an open meter
/// connection is never probed, so periodic scans cannot interfere with a
/// connection.
class UsbMeterDiscovery implements MeterDiscovery {
  UsbBackend? _backendInstance;
  Map<String, UsbDevice> _devices = {};
  final Map<String, MeterCandidate> _lastCandidates = {};

  /// Cables with an open [MeterLink].
  final Set<String> _inUse = {};
  Future<void> _queue = Future.value();

  /// Created lazily so a missing libusb / WebUSB shows up as a scan error.
  UsbBackend get _backend => _backendInstance ??= createUsbBackend();

  static const _probeTimeout = Duration(milliseconds: 1500);

  @override
  bool get canRequestDevice =>
      _backend.requestDeviceRequired && !usbPermissionsAutomatic(_backend);

  @override
  bool get autoSelectSingle => usbPermissionsAutomatic(_backend);

  /// Runs [action] after all previously queued scans/connects.
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<MeterCandidate>> scan() => _exclusive(() async {
    await requestMissingUsbPermissions(_backend, _filters);
    final devices = await _backend.getDevices(filters: _filters);
    final found = <String, UsbDevice>{};
    final candidates = <MeterCandidate>[];
    for (final device in devices) {
      final id = _uniqueId(device.descriptor, found);
      if (_inUse.contains(id)) {
        // Keep the handle that is open; don't probe a cable in use.
        found[id] = _devices[id] ?? device;
        final last = _lastCandidates[id];
        if (last != null) candidates.add(last);
        continue;
      }
      found[id] = device;
      final candidate = await _probe(id, device);
      _lastCandidates[id] = candidate;
      candidates.add(candidate);
    }
    _devices = found;
    _lastCandidates.removeWhere((id, _) => !found.containsKey(id));
    return candidates;
  });

  Future<MeterCandidate> _probe(String id, UsbDevice device) async {
    final cableName = _cableName(device.descriptor);
    SerialChannel? serial;
    try {
      serial = await _openSerial(_backend, device);
      final client = FlukeClient(serial);
      final identity = await client.identify(timeout: _probeTimeout);
      MeterProperties? properties;
      try {
        properties = await client.readProperties();
      } catch (_) {
        // Only shown as extra information in the device list.
      }
      return MeterCandidate(
        id: id,
        cableName: cableName,
        identity: identity,
        properties: properties,
      );
    } catch (e) {
      return MeterCandidate(id: id, cableName: cableName, error: e);
    } finally {
      await serial?.close();
    }
  }

  @override
  void dispose() {
    final backend = _backendInstance;
    if (backend != null) disposeUsbBackend(backend);
  }

  /// The cables and adapters plugged in, without probing them, for the
  /// serial monitor.
  Future<List<SerialPortInfo>> listSerialPorts() => _exclusive(() async {
    await requestMissingUsbPermissions(_backend, _filters);
    final devices = await _backend.getDevices(filters: _filters);
    final found = <String, UsbDevice>{};
    for (final device in devices) {
      final id = _uniqueId(device.descriptor, found);
      found[id] = _inUse.contains(id) ? _devices[id] ?? device : device;
    }
    _devices = found;
    return [
      for (final MapEntry(key: id, value: device) in found.entries)
        SerialPortInfo(id, _cableName(device.descriptor)),
    ];
  });

  /// Opens the cable or adapter [id] (from [listSerialPorts]) as a raw
  /// serial channel. It counts as in use until the channel is closed.
  Future<SerialChannel> openSerialPort(String id) => _exclusive(() async {
    final device = _devices[id];
    if (device == null) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceGone);
    }
    if (_inUse.contains(id)) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceInUse);
    }
    final serial = await _openSerial(_backend, device);
    _inUse.add(id);
    return _ReleasingChannel(serial, () => _inUse.remove(id));
  });

  @override
  Future<void> requestDevice() async {
    if (!_backend.requestDeviceRequired) return;
    await _backend.requestDevice(filters: _filters);
  }

  @override
  Future<MeterLink> connect(MeterCandidate candidate) => _exclusive(() async {
    final id = candidate.id;
    final device = _devices[id];
    if (device == null) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceGone);
    }
    if (_inUse.contains(id)) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceInUse);
    }
    final client = FlukeClient(await _openSerial(_backend, device));
    _inUse.add(id);
    return ReleasingLink(client, () => _inUse.remove(id));
  });

  @override
  Stream<void> get onDevicesChanged {
    final UsbBackend backend;
    try {
      backend = _backend;
    } catch (_) {
      return const Stream.empty();
    }
    final controller = StreamController<void>();
    final subs = <StreamSubscription<UsbDevice>>[];
    controller
      ..onListen = () {
        subs
          ..add(
            backend.onDeviceConnected
                .where(_isMeterCable)
                .listen(controller.add),
          )
          ..add(
            backend.onDeviceDisconnected
                .where(_isMeterCable)
                .listen(controller.add),
          );
      }
      ..onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    return controller.stream;
  }

  static String _uniqueId(UsbDeviceDescriptor d, Map<String, UsbDevice> taken) {
    final base =
        '${d.vendorId.toRadixString(16)}:${d.productId.toRadixString(16)}:'
        '${d.serialNumber ?? ''}';
    var id = base;
    for (var i = 2; taken.containsKey(id); i++) {
      id = '$base#$i';
    }
    return id;
  }

  static String _cableName(UsbDeviceDescriptor d) {
    // The ESP32's USB controller reports a generic product name.
    final name = d.vendorId == espressifVendorId
        ? irAdapterUsbName
        : d.productName ??
              '${d.vendorId.toRadixString(16).padLeft(4, '0')}:'
                  '${d.productId.toRadixString(16).padLeft(4, '0')}';
    return d.serialNumber == null ? name : '$name (${d.serialNumber})';
  }
}

/// A cable or adapter for the serial monitor.
class SerialPortInfo {
  const SerialPortInfo(this.id, this.name);

  final String id;
  final String name;
}

/// Marks the cable or adapter as free again when the channel is closed.
class _ReleasingChannel implements SerialChannel {
  _ReleasingChannel(this._inner, this._release);

  final SerialChannel _inner;
  final void Function() _release;

  @override
  Future<void> write(List<int> data) => _inner.write(data);

  @override
  Future<List<int>> read() => _inner.read();

  @override
  Stream<void> get onRemoved => _inner.onRemoved;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _release();
    }
  }
}
