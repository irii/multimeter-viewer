import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../adapter.dart';
import '../serial_channel.dart';
import 'ble_serial.dart';

/// Whether a device advertising [advertised] belongs to [filters]. A device
/// that advertises no services could be any of them.
bool bleDeviceMatches(List<BleFilter> filters, List<String> advertised) {
  if (advertised.isEmpty) return filters.isNotEmpty;
  final services = {for (final uuid in advertised) uuid.toLowerCase()};
  return filters.any((f) => services.contains(f.service.toLowerCase()));
}

/// [Adapter] over Bluetooth LE serial services.
///
/// Scans in the background while the app runs; a device not advertising for
/// a while counts as gone unless it is open.
class BleAdapter with AdapterQueue implements Adapter<BleFilter> {
  final List<BleFilter> _filters = [];
  final Map<String, BleDevice> _seen = {};
  final Map<String, DateTime> _seenAt = {};
  final Set<String> _inUse = {};
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<AvailabilityState>? _availabilitySub;
  bool _scanning = false;
  bool _permissionDenied = false;

  /// Running stop of a scan whose filters are out of date.
  Future<void> _stopping = Future.value();

  static const _idPrefix = 'ble:';

  /// A device not advertising for this long counts as gone.
  static const _forgetAfter = Duration(seconds: 15);

  /// Whether this platform can use Bluetooth. Not in the browser, where Web
  /// Bluetooth needs its own device chooser.
  static bool get supported => !kIsWeb;

  @override
  AdapterTransport get transport => AdapterTransport.bluetooth;

  @override
  bool get canRequestDevice => false;

  @override
  bool get autoSelectSingle => defaultTargetPlatform == TargetPlatform.android;

  /// A device may be switched on later, but connecting to it takes long.
  @override
  Duration? get reprobeAfter => const Duration(seconds: 15);

  @override
  void attachFilter(BleFilter filter) {
    _filters.add(filter);
    _restartScan();
  }

  @override
  void detachFilter(BleFilter filter) {
    _filters.remove(filter);
    _restartScan();
  }

  /// The running scan looks for the old filters; the next [listDevices]
  /// starts a new one.
  void _restartScan() {
    if (!_scanning) return;
    _scanning = false;
    _stopping = UniversalBle.stopScan().catchError((_) {});
  }

  /// Starts the background scan if Bluetooth is on and allowed. Returns
  /// whether it runs; without Bluetooth the list just stays empty.
  Future<bool> _ensureScanning() async {
    if (_scanning) return true;
    if (_filters.isEmpty) return false;
    await _stopping;
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
      scanFilter: ScanFilter(
        withServices: [for (final filter in _filters) filter.service],
      ),
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
  Future<List<AdapterDevice>> listDevices({List<BleFilter>? only}) async {
    if (!await _ensureScanning()) return [];
    final now = DateTime.now();
    _seenAt.removeWhere(
      (id, at) => !_inUse.contains(id) && now.difference(at) > _forgetAfter,
    );
    _seen.removeWhere((id, _) => !_seenAt.containsKey(id));
    return [
      for (final device in _seen.values)
        if (bleDeviceMatches(only ?? _filters, device.services))
          AdapterDevice(
            id: '$_idPrefix${device.deviceId}',
            name: device.name ?? device.deviceId,
            inUse: _inUse.contains(device.deviceId),
          ),
    ];
  }

  @override
  Future<void> requestDevice() async {}

  @override
  Future<SerialChannel> open(String deviceId) async {
    final id = deviceId.substring(_idPrefix.length);
    if (!_seen.containsKey(id) || _filters.isEmpty) {
      throw const AdapterException(AdapterError.deviceGone);
    }
    if (_inUse.contains(id)) {
      throw const AdapterException(AdapterError.deviceInUse);
    }
    final serial = await BleSerial.open(id, List.of(_filters));
    _inUse.add(id);
    return ReleasingChannel(serial, () => _inUse.remove(id));
  }

  /// Fires when a new device shows up.
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
