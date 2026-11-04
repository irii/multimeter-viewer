import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/adapters/adapter.dart';
import 'package:multimeter_viewer/adapters/ble/ble_adapter.dart';
import 'package:multimeter_viewer/adapters/ble/ble_serial.dart';
import 'package:multimeter_viewer/adapters/serial_channel.dart';
import 'package:multimeter_viewer/adapters/usb/usb_adapter.dart';
import 'package:multimeter_viewer/meter/adapter_meter_discovery.dart';
import 'package:multimeter_viewer/meter/meter_discovery.dart';
import 'package:multimeter_viewer/meter/meter_link.dart';
import 'package:multimeter_viewer/meter/meter_protocol.dart';
import 'package:multimeter_viewer/meter/model/model.dart';

import 'fakes.dart';

const _identity = MeterIdentity(model: 'TEST 1', firmware: 'V1', serial: '123');

/// Devices are keyed by id; a filter is the kind of device it matches.
class _FakeAdapter with AdapterQueue implements Adapter<String> {
  _FakeAdapter({this.reprobeAfter});

  @override
  final Duration? reprobeAfter;

  final Map<String, String> kinds = {};
  final List<String> filters = [];
  final Set<String> inUse = {};
  final changes = StreamController<void>.broadcast();
  int active = 0;
  int maxActive = 0;

  @override
  AdapterTransport get transport => AdapterTransport.bluetooth;

  @override
  bool get canRequestDevice => true;

  @override
  bool get autoSelectSingle => true;

  @override
  void attachFilter(String filter) => filters.add(filter);

  @override
  void detachFilter(String filter) => filters.remove(filter);

  @override
  Future<List<AdapterDevice>> listDevices({List<String>? only}) async => [
    for (final MapEntry(key: id, value: kind) in kinds.entries)
      if (filters.contains(kind) && (only?.contains(kind) ?? true))
        AdapterDevice(id: id, name: 'Device $id', inUse: inUse.contains(id)),
  ];

  @override
  Future<void> requestDevice() async {}

  @override
  Future<SerialChannel> open(String deviceId) async {
    if (!kinds.containsKey(deviceId)) {
      throw const AdapterException(AdapterError.deviceGone);
    }
    if (inUse.contains(deviceId)) {
      throw const AdapterException(AdapterError.deviceInUse);
    }
    inUse.add(deviceId);
    active++;
    if (active > maxActive) maxActive = active;
    return ReleasingChannel(FakeChannel(), () {
      active--;
      inUse.remove(deviceId);
    });
  }

  @override
  Stream<void> get onDevicesChanged => changes.stream;

  bool disposed = false;

  @override
  void dispose() => disposed = true;
}

class _FakeProtocol implements MeterProtocol {
  _FakeProtocol({this.error});

  final Object? error;
  int probes = 0;
  int attached = 0;

  @override
  Future<MeterProbe> probe(
    SerialChannel channel, {
    required Duration timeout,
  }) async {
    probes++;
    await pumpEventQueue(times: 1);
    if (error != null) throw error!;
    return const MeterProbe(
      identity: _identity,
      properties: MeterProperties(site: 'Lab'),
    );
  }

  @override
  MeterLink attach(SerialChannel channel) {
    attached++;
    return _ChannelLink(channel);
  }
}

/// Closes its channel like a real link does.
class _ChannelLink extends FakeLink {
  _ChannelLink(this.channel);

  final SerialChannel channel;

  @override
  Future<void> close() => channel.close();
}

void main() {
  late _FakeAdapter adapter;
  late _FakeProtocol protocol;
  late AdapterMeterDiscovery<String> discovery;

  setUp(() {
    adapter = _FakeAdapter()..kinds['a'] = 'meter';
    protocol = _FakeProtocol();
    discovery = AdapterMeterDiscovery(
      adapter: adapter,
      filters: const ['meter'],
      protocol: protocol,
    );
  });

  test('a device with a meter becomes a candidate', () async {
    final candidates = await discovery.scan();
    expect(candidates, const [
      MeterCandidate(
        id: 'a',
        cableName: 'Device a',
        transport: AdapterTransport.bluetooth,
        identity: _identity,
        properties: MeterProperties(site: 'Lab'),
      ),
    ]);
    expect(adapter.inUse, isEmpty, reason: 'the probe closes its channel');
  });

  test('a device without a meter reports why', () async {
    discovery = AdapterMeterDiscovery(
      adapter: adapter,
      filters: const ['meter'],
      protocol: _FakeProtocol(error: const MeterTimeoutException('ID')),
    );
    final candidate = (await discovery.scan()).single;
    expect(candidate.hasMeter, isFalse);
    expect(candidate.error, const MeterTimeoutException('ID'));
    expect(adapter.inUse, isEmpty);
  });

  group('filters', () {
    test('are attached on creation and detached on dispose', () {
      expect(adapter.filters, ['meter']);
      discovery.dispose();
      expect(adapter.filters, isEmpty);
      expect(adapter.disposed, isFalse, reason: 'the owner disposes it');
    });

    test('kinds of meters sharing an adapter only see their devices', () async {
      adapter.kinds['b'] = 'other';
      final other = AdapterMeterDiscovery(
        adapter: adapter,
        filters: const ['other'],
        protocol: _FakeProtocol(),
      );
      expect((await discovery.scan()).map((c) => c.id), ['a']);
      expect((await other.scan()).map((c) => c.id), ['b']);

      other.dispose();
      expect((await adapter.listDevices()).map((d) => d.id), ['a']);
    });

    test('sharing an adapter never opens two devices at once', () async {
      adapter.kinds['b'] = 'other';
      final other = AdapterMeterDiscovery(
        adapter: adapter,
        filters: const ['other'],
        protocol: _FakeProtocol(),
      );
      await Future.wait([discovery.scan(), other.scan()]);
      expect(adapter.maxActive, 1);
    });
  });

  group('open connection', () {
    late MeterCandidate candidate;
    late MeterLink link;

    setUp(() async {
      candidate = (await discovery.scan()).single;
      link = await discovery.connect(candidate);
    });

    test('is never probed, the last result stays listed', () async {
      expect(await discovery.scan(), [candidate]);
      expect(protocol.probes, 1);
    });

    test('blocks a second connection until it is closed', () async {
      await expectLater(
        discovery.connect(candidate),
        throwsA(const AdapterException(AdapterError.deviceInUse)),
      );
      await link.close();
      expect(adapter.inUse, isEmpty);
      await discovery.connect(candidate);
    });
  });

  test('an unknown device in use is not probed or listed', () async {
    adapter.inUse.add('a');
    expect(await discovery.scan(), isEmpty);
    expect(protocol.probes, 0);
  });

  test('connecting to a device that is gone fails', () async {
    final candidate = (await discovery.scan()).single;
    adapter.kinds.clear();
    await expectLater(
      discovery.connect(candidate),
      throwsA(const AdapterException(AdapterError.deviceGone)),
    );
  });

  test('probes on every scan without reprobeAfter', () async {
    await discovery.scan();
    await discovery.scan();
    expect(protocol.probes, 2);
  });

  test('keeps a probe result for reprobeAfter', () async {
    var now = DateTime(2026);
    discovery = AdapterMeterDiscovery(
      adapter: _FakeAdapter(reprobeAfter: const Duration(seconds: 15))
        ..kinds['a'] = 'meter',
      filters: const ['meter'],
      protocol: protocol,
      clock: () => now,
    );
    await discovery.scan();
    now = now.add(const Duration(seconds: 14));
    await discovery.scan();
    expect(protocol.probes, 1);

    now = now.add(const Duration(seconds: 1));
    await discovery.scan();
    expect(protocol.probes, 2);
  });

  test('a device that comes back is probed again', () async {
    discovery = AdapterMeterDiscovery(
      adapter: adapter = _FakeAdapter(reprobeAfter: const Duration(hours: 1))
        ..kinds['a'] = 'meter',
      filters: const ['meter'],
      protocol: protocol,
    );
    await discovery.scan();
    adapter.kinds.clear();
    expect(await discovery.scan(), isEmpty);
    adapter.kinds['a'] = 'meter';
    await discovery.scan();
    expect(protocol.probes, 2);
  });

  test('passes the adapter through', () async {
    expect(discovery.canRequestDevice, isTrue);
    expect(discovery.autoSelectSingle, isTrue);

    var changes = 0;
    final sub = discovery.onDevicesChanged.listen((_) => changes++);
    adapter.changes.add(null);
    await pumpEventQueue();
    expect(changes, 1);
    await sub.cancel();
  });

  group('USB filters', () {
    const vendorOnly = UsbFilter(
      vendorId: 0x0403,
      driver: UsbSerialDriver.ftdi,
    );
    const exact = UsbFilter(
      vendorId: 0x303A,
      productId: 0x1001,
      driver: UsbSerialDriver.cdc,
    );
    const filters = [vendorOnly, exact];

    test('a filter without a product ID accepts any product', () {
      expect(usbFilterFor(filters, 0x0403, 0x6001), vendorOnly);
      expect(usbFilterFor(filters, 0x0403, 0x6015), vendorOnly);
    });

    test('a product ID must match', () {
      expect(usbFilterFor(filters, 0x303A, 0x1001), exact);
      expect(usbFilterFor(filters, 0x303A, 0x1002), isNull);
    });

    test('other vendors are not accepted', () {
      expect(usbFilterFor(filters, 0x1234, 0x6001), isNull);
    });
  });

  group('BLE filters', () {
    const first = BleFilter(service: 'AAAA', write: 'w1', notify: 'n1');
    const second = BleFilter(service: 'bbbb', write: 'w2', notify: 'n2');

    test('picks the filter of the offered service, ignoring case', () {
      expect(bleFilterFor([first, second], ['1234', 'BBBB']), second);
      expect(bleFilterFor([first, second], ['aaaa']), first);
    });

    test('falls back to the first filter', () {
      expect(bleFilterFor([first, second], const []), first);
    });

    test('a device belongs to the filter of an advertised service', () {
      expect(bleDeviceMatches([first], ['aaaa']), isTrue);
      expect(bleDeviceMatches([first], ['bbbb']), isFalse);
    });

    test('a device advertising no services could be any', () {
      expect(bleDeviceMatches([first], const []), isTrue);
      expect(bleDeviceMatches(const [], const []), isFalse);
    });
  });
}
