import 'dart:async';

import '../adapters/adapter.dart';
import '../adapters/serial_channel.dart';
import 'meter_discovery.dart';
import 'meter_link.dart';
import 'meter_protocol.dart';

/// [MeterDiscovery] of one kind of meter over one [Adapter], which it may share
/// with other kinds of meters: attaches its filters and asks the devices they
/// match with [MeterProtocol] who they are.
///
/// Scans and connects use the adapter's queue, and a device with an open
/// connection is never probed, so periodic scans cannot interfere with it.
class AdapterMeterDiscovery<F> implements MeterDiscovery {
  AdapterMeterDiscovery({
    required this._adapter,
    required this._filters,
    required this._protocol,
    this._probeTimeout = const Duration(milliseconds: 1500),
    this._clock = DateTime.now,
  }) {
    _filters.forEach(_adapter.attachFilter);
  }

  final Adapter<F> _adapter;
  final List<F> _filters;
  final MeterProtocol _protocol;
  final Duration _probeTimeout;
  final DateTime Function() _clock;
  final Map<String, ({MeterCandidate candidate, DateTime at})> _probed = {};

  /// One kind of meter over one transport; its device class names it.
  @override
  List<String> get supportedDevices => const [];

  @override
  bool get canRequestDevice => _adapter.canRequestDevice;

  @override
  bool get autoSelectSingle => _adapter.autoSelectSingle;

  @override
  Future<List<MeterCandidate>> scan() => _adapter.exclusive(() async {
    final devices = await _adapter.listDevices(only: _filters);
    final ids = {for (final d in devices) d.id};
    _probed.removeWhere((id, _) => !ids.contains(id));

    final now = _clock();
    final reprobeAfter = _adapter.reprobeAfter;
    final candidates = <MeterCandidate>[];
    for (final device in devices) {
      final known = _probed[device.id];
      if (known != null &&
          (device.inUse ||
              (reprobeAfter != null &&
                  now.difference(known.at) < reprobeAfter))) {
        candidates.add(known.candidate);
        continue;
      }
      // Never probe a device in use.
      if (device.inUse) continue;
      final candidate = await _probe(device);
      _probed[device.id] = (candidate: candidate, at: _clock());
      candidates.add(candidate);
    }
    return candidates;
  });

  Future<MeterCandidate> _probe(AdapterDevice device) async {
    SerialChannel? channel;
    try {
      channel = await _adapter.open(device.id);
      final probe = await _protocol.probe(channel, timeout: _probeTimeout);
      return MeterCandidate(
        id: device.id,
        cableName: device.name,
        transport: _adapter.transport,
        identity: probe.identity,
        properties: probe.properties,
      );
    } catch (e) {
      return MeterCandidate(
        id: device.id,
        cableName: device.name,
        transport: _adapter.transport,
        error: e,
      );
    } finally {
      await channel?.close().catchError((_) {});
    }
  }

  @override
  Future<void> requestDevice() => _adapter.requestDevice();

  @override
  Future<MeterLink> connect(MeterCandidate candidate) => _adapter.exclusive(
    () async => _protocol.attach(await _adapter.open(candidate.id)),
  );

  @override
  Stream<void> get onDevicesChanged => _adapter.onDevicesChanged;

  /// Detaches the filters; the adapter stays with whoever created it.
  @override
  void dispose() => _filters.forEach(_adapter.detachFilter);
}
