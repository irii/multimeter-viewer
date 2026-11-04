import 'package:multimeter_viewer/meter/model/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/meter/meter_discovery.dart';

import 'fakes.dart';

const _bleCandidate = MeterCandidate(
  id: 'ble:AA:BB',
  cableName: 'MMV-IR-AABB',
  transport: AdapterTransport.bluetooth,
  identity: fluke287Identity,
);

void main() {
  late FakeDiscovery usb;
  late FakeDiscovery ble;
  late CompositeMeterDiscovery discovery;

  setUp(() {
    usb = FakeDiscovery();
    ble = FakeDiscovery(candidates: [_bleCandidate], link: FakeLink());
    discovery = CompositeMeterDiscovery([usb, ble]);
  });

  test('lists USB cables first, then Bluetooth adapters', () async {
    expect(await discovery.scan(), [fakeCandidate, _bleCandidate]);
  });

  test('connects through the discovery that listed the candidate', () async {
    await discovery.scan();
    expect(await discovery.connect(_bleCandidate), same(ble.link));
    expect(await discovery.connect(fakeCandidate), same(usb.link));
  });

  test('a failing transport only hides its own devices', () async {
    usb.scanError = const MeterTimeoutException('ID');
    expect(await discovery.scan(), [_bleCandidate]);

    ble.candidates = [];
    await expectLater(
      discovery.scan(),
      throwsA(const MeterTimeoutException('ID')),
    );
  });

  test('supports the devices of all parts', () {
    expect(discovery.supportedDevices, [
      'Fluke 287',
      'Fluke 289',
      'Fluke 287',
      'Fluke 289',
    ]);
  });

  test('a candidate unknown to the last scan is gone', () async {
    await expectLater(
      discovery.connect(fakeCandidate),
      throwsA(const AdapterException(AdapterError.deviceGone)),
    );
  });

  test('a device listed twice counts for the part with a meter', () async {
    const noMeter = MeterCandidate(
      id: 'same',
      cableName: 'Cable',
      error: MeterTimeoutException('ID'),
    );
    const withMeter = MeterCandidate(
      id: 'same',
      cableName: 'Cable',
      identity: fluke287Identity,
    );
    usb.candidates = [noMeter];
    ble.candidates = [withMeter];

    expect(await discovery.scan(), [withMeter]);
    expect(await discovery.connect(withMeter), same(ble.link));
  });

  test('device changes of all parts, dispose of all', () async {
    var changes = 0;
    final sub = discovery.onDevicesChanged.listen((_) => changes++);
    usb.changes.add(null);
    ble.changes.add(null);
    await pumpEventQueue();
    expect(changes, 2);
    await sub.cancel();

    var ownerDisposed = false;
    CompositeMeterDiscovery(
      [usb, ble],
      onDispose: () {
        ownerDisposed = usb.disposed && ble.disposed;
      },
    ).dispose();
    expect(ownerDisposed, isTrue, reason: 'parts first, then the owner');
  });
}
