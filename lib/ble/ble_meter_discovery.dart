import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../fluke/fluke_client.dart';
import '../fluke/meter_discovery.dart';
import '../fluke/releasing_link.dart';
import 'ble_serial.dart';

/// [MeterDiscovery] over Bluetooth IR adapters.
///
/// Scans in the background while the app runs. Each adapter is asked for
/// its meter when it shows up and again every [_reprobeAfter] (the meter may
/// be switched on later); in between, a scan returns what is known. An
/// adapter with an open connection is never probed.
class BleMeterDiscovery implements MeterDiscovery {
  final Map<String, BleDevice> _seen = {};
  final Map<String, DateTime> _seenAt = {};
  final Map<String, (MeterCandidate, DateTime)> _probed = {};
  final Set<String> _inUse = {};
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<AvailabilityState>? _availabilitySub;
  bool _scanning = false;
  bool _permissionDenied = false;
  Future<void> _queue = Future.value();

  static const _idPrefix = 'ble:';
  static const _probeTimeout = Duration(milliseconds: 1500);

  /// An adapter not advertising for this long counts as gone.
  static const _forgetAfter = Duration(seconds: 15);
  static const _reprobeAfter = Duration(seconds: 15);

  /// Whether this platform can use the adapter. Not in the browser, where
  /// Web Bluetooth needs its own device chooser.
  static bool get supported => !kIsWeb;

  @override
  bool get canRequestDevice => false;

  @override
  bool get autoSelectSingle => defaultTargetPlatform == TargetPlatform.android;

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Starts the background scan if Bluetooth is on and allowed. Returns
  /// whether it runs; without Bluetooth the list just stays empty.
  Future<bool> _ensureScanning() async {
    if (_scanning) return true;
    _availabilitySub ??= UniversalBle.availabilityStream.listen((state) {
      if (state != AvailabilityState.poweredOn) {
        _scanning = false;
        _seen.clear();
        _seenAt.clear();
      }
    });
    final state = await UniversalBle.getBluetoothAvailabilityState();
    if (state != AvailabilityState.poweredOn) return false;
    if (!await UniversalBle.hasPermissions()) {
      if (_permissionDenied) return false;
      try {
        await UniversalBle.requestPermissions();
      } catch (_) {
        // Asked once; the user can allow it in the system settings.
        _permissionDenied = true;
        return false;
      }
    }
    _scanSub ??= UniversalBle.scanStream.listen(_onScanResult);
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [IrAdapterBle.service]),
    );
    _scanning = true;
    return true;
  }

  void _onScanResult(BleDevice device) {
    final isNew = !_seen.containsKey(device.deviceId);
    _seen[device.deviceId] = device;
    _seenAt[device.deviceId] = DateTime.now();
    if (isNew) _changes.add(null);
  }

  @override
  Future<List<MeterCandidate>> scan() => _exclusive(() async {
    if (!await _ensureScanning()) return [];
    final now = DateTime.now();
    _seenAt.removeWhere(
      (id, at) => !_inUse.contains(id) && now.difference(at) > _forgetAfter,
    );
    _seen.removeWhere((id, _) => !_seenAt.containsKey(id));
    _probed.removeWhere((id, _) => !_seen.containsKey(id));

    final candidates = <MeterCandidate>[];
    for (final device in _seen.values) {
      final id = device.deviceId;
      final known = _probed[id];
      if (known != null &&
          (_inUse.contains(id) || now.difference(known.$2) < _reprobeAfter)) {
        candidates.add(known.$1);
        continue;
      }
      final candidate = await _probe(device);
      _probed[id] = (candidate, DateTime.now());
      candidates.add(candidate);
    }
    return candidates;
  });

  Future<MeterCandidate> _probe(BleDevice device) async {
    final id = '$_idPrefix${device.deviceId}';
    final name = device.name ?? device.deviceId;
    BleSerial? serial;
    try {
      serial = await BleSerial.open(device.deviceId);
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
        cableName: name,
        transport: MeterTransport.bluetooth,
        identity: identity,
        properties: properties,
      );
    } catch (e) {
      return MeterCandidate(
        id: id,
        cableName: name,
        transport: MeterTransport.bluetooth,
        error: e,
      );
    } finally {
      await serial?.close().catchError((_) {});
    }
  }

  @override
  Future<void> requestDevice() async {}

  @override
  Future<MeterLink> connect(MeterCandidate candidate) => _exclusive(() async {
    final deviceId = candidate.id.substring(_idPrefix.length);
    if (!_seen.containsKey(deviceId)) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceGone);
    }
    if (_inUse.contains(deviceId)) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceInUse);
    }
    final client = FlukeClient(await BleSerial.open(deviceId));
    _inUse.add(deviceId);
    return ReleasingLink(client, () => _inUse.remove(deviceId));
  });

  /// Fires when a new adapter shows up.
  @override
  Stream<void> get onDevicesChanged => _changes.stream;

  @override
  void dispose() {
    _scanSub?.cancel();
    _availabilitySub?.cancel();
    if (_scanning) UniversalBle.stopScan().catchError((_) {});
    _scanning = false;
    _changes.close();
  }
}
