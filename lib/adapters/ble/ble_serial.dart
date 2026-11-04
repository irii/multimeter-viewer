import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../serial_channel.dart';

/// Bluetooth LE devices to offer: those with this GATT serial service.
class BleFilter {
  const BleFilter({
    required this.service,
    required this.write,
    required this.notify,
  });

  final String service;

  /// App → device.
  final String write;

  /// Device → app.
  final String notify;
}

/// The filter whose service the device offers. Falls back to the first one,
/// so a device reporting its UUIDs in another format still connects.
BleFilter bleFilterFor(List<BleFilter> filters, Iterable<String> serviceUuids) {
  final offered = {for (final uuid in serviceUuids) uuid.toLowerCase()};
  return filters.firstWhere(
    (filter) => offered.contains(filter.service.toLowerCase()),
    orElse: () => filters.first,
  );
}

/// [SerialChannel] over a Bluetooth LE serial service.
class BleSerial implements SerialChannel {
  BleSerial._(this.deviceId, this._filter, this._maxWrite);

  final String deviceId;
  final BleFilter _filter;

  /// Largest write the connection takes (MTU minus the ATT header).
  final int _maxWrite;
  final List<int> _received = [];
  final _removed = StreamController<void>.broadcast();
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<bool>? _connectionSub;
  bool _closed = false;

  static const _connectTimeout = Duration(seconds: 8);

  /// Connects to the device [deviceId] and subscribes to its answers.
  static Future<BleSerial> open(
    String deviceId,
    List<BleFilter> filters,
  ) async {
    await UniversalBle.connect(deviceId, timeout: _connectTimeout);
    try {
      final services = await UniversalBle.discoverServices(deviceId);
      final filter = bleFilterFor(filters, [
        for (final service in services) service.uuid,
      ]);
      var mtu = 23;
      try {
        mtu = await UniversalBle.requestMtu(deviceId, 247);
      } catch (_) {
        // Keep the default; commands are short anyway.
      }
      final serial = BleSerial._(deviceId, filter, mtu - 3);
      serial._valueSub = UniversalBle.characteristicValueStream(
        deviceId,
        filter.notify,
      ).listen(serial._received.addAll);
      serial._connectionSub = UniversalBle.connectionStream(deviceId)
          .listen((connected) {
            if (!connected && !serial._closed) serial._removed.add(null);
          });
      await UniversalBle.subscribeNotifications(
        deviceId,
        filter.service,
        filter.notify,
      );
      return serial;
    } catch (_) {
      await UniversalBle.disconnect(deviceId).catchError((_) {});
      rethrow;
    }
  }

  @override
  Future<void> write(List<int> data) async {
    for (var i = 0; i < data.length; i += _maxWrite) {
      final end = i + _maxWrite < data.length ? i + _maxWrite : data.length;
      await UniversalBle.write(
        deviceId,
        _filter.service,
        _filter.write,
        Uint8List.fromList(data.sublist(i, end)),
      );
    }
  }

  @override
  Future<List<int>> read() async {
    if (_received.isEmpty) return const [];
    final bytes = List<int>.of(_received);
    _received.clear();
    return bytes;
  }

  @override
  Stream<void> get onRemoved => _removed.stream;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _valueSub?.cancel();
    await _connectionSub?.cancel();
    try {
      await UniversalBle.disconnect(deviceId);
    } finally {
      await _removed.close();
    }
  }
}
