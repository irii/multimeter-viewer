import 'dart:async';

import 'package:unified_usb/unified_usb.dart';

import '../fluke/fluke_client.dart';
import '../fluke/meter_discovery.dart';
import '../fluke/qdda.dart';
import 'backend.dart';
import 'ftdi_serial.dart';

const _filters = [UsbDeviceFilter(vendorId: ftdiVendorId)];

/// [MeterDiscovery] over FTDI cables via `unified_usb`.
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
    FtdiSerial? serial;
    try {
      serial = await FtdiSerial.open(_backend, device);
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
    final client = FlukeClient(await FtdiSerial.open(_backend, device));
    _inUse.add(id);
    return _ReleasingLink(client, () => _inUse.remove(id));
  });

  @override
  Stream<void> get onDevicesChanged {
    final UsbBackend backend;
    try {
      backend = _backend;
    } catch (_) {
      return const Stream.empty();
    }
    bool isFtdi(UsbDevice d) => d.descriptor.vendorId == ftdiVendorId;
    final controller = StreamController<void>();
    final subs = <StreamSubscription<UsbDevice>>[];
    controller
      ..onListen = () {
        subs
          ..add(backend.onDeviceConnected.where(isFtdi).listen(controller.add))
          ..add(
            backend.onDeviceDisconnected.where(isFtdi).listen(controller.add),
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
    final name =
        d.productName ??
        '${d.vendorId.toRadixString(16).padLeft(4, '0')}:'
            '${d.productId.toRadixString(16).padLeft(4, '0')}';
    return d.serialNumber == null ? name : '$name (${d.serialNumber})';
  }
}

/// Marks the cable as free again when the connection is closed.
class _ReleasingLink implements MeterLink {
  _ReleasingLink(this._inner, this._release);

  final MeterLink _inner;
  final void Function() _release;

  @override
  Future<MeterIdentity> identify() => _inner.identify();

  @override
  Future<QddaResponse> queryDisplay() => _inner.queryDisplay();

  @override
  Future<MeterProperties> readProperties() => _inner.readProperties();

  @override
  Future<void> writeProperty(String name, String value) =>
      _inner.writeProperty(name, value);

  @override
  Stream<void> get onRemoved => _inner.onRemoved;

  @override
  MeterMemory get memory => _inner.memory;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _release();
    }
  }
}
