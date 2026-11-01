import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../fluke/fluke_client.dart';

/// The Bluetooth IR adapter (`firmware/ir-ble-adapter`): an ESP32 that sends
/// the bytes it receives over Bluetooth LE to the meter's IR port and
/// notifies the bytes the meter answers. The meter protocol is the same as
/// over the USB cable.
abstract final class IrAdapterBle {
  static const service = 'ca7c33cd-93df-40a9-83c7-4c9e4ee57a33';

  /// App → meter (write).
  static const toMeter = '077fee1f-2aa0-4b7a-8adb-8c1f7c51310b';

  /// Meter → app (notify).
  static const fromMeter = '9612beb0-f6ef-41ee-9a61-d7d51add4703';

  /// Advertised name prefix, followed by part of the adapter's address.
  static const namePrefix = 'MMV-IR';
}

/// [SerialChannel] over the Bluetooth IR adapter.
class BleSerial implements SerialChannel {
  BleSerial._(this.deviceId, this._maxWrite);

  final String deviceId;

  /// Largest write the connection takes (MTU minus the ATT header).
  final int _maxWrite;
  final List<int> _received = [];
  final _removed = StreamController<void>.broadcast();
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<bool>? _connectionSub;
  bool _closed = false;

  static const _connectTimeout = Duration(seconds: 8);

  /// Connects to the adapter [deviceId] and subscribes to the meter's
  /// answers.
  static Future<BleSerial> open(String deviceId) async {
    await UniversalBle.connect(deviceId, timeout: _connectTimeout);
    try {
      await UniversalBle.discoverServices(deviceId);
      var mtu = 23;
      try {
        mtu = await UniversalBle.requestMtu(deviceId, 247);
      } catch (_) {
        // Keep the default; commands are short anyway.
      }
      final serial = BleSerial._(deviceId, mtu - 3);
      serial._valueSub = UniversalBle.characteristicValueStream(
        deviceId,
        IrAdapterBle.fromMeter,
      ).listen(serial._received.addAll);
      serial._connectionSub = UniversalBle.connectionStream(deviceId)
          .listen((connected) {
            if (!connected && !serial._closed) serial._removed.add(null);
          });
      await UniversalBle.subscribeNotifications(
        deviceId,
        IrAdapterBle.service,
        IrAdapterBle.fromMeter,
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
        IrAdapterBle.service,
        IrAdapterBle.toMeter,
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
