import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/fluke/meter_discovery.dart';

import 'fakes.dart';

const _bleCandidate = MeterCandidate(
  id: 'ble:AA:BB',
  cableName: 'MMV-IR-AABB',
  transport: MeterTransport.bluetooth,
  identity: fluke287Identity,
);

void main() {
  late FakeDiscovery usb;
  late FakeDiscovery ble;
  late CompositeMeterDiscovery discovery;

  setUp(() {
    usb = FakeDiscovery();
    ble = FakeDiscovery(candidates: [_bleCandidate], link: FakeLink());
    discovery = CompositeMeterDiscovery({
      MeterTransport.usb: usb,
      MeterTransport.bluetooth: ble,
    });
  });

  test('lists USB cables first, then Bluetooth adapters', () async {
    expect(await discovery.scan(), [fakeCandidate, _bleCandidate]);
  });

  test('connects through the transport of the candidate', () async {
    expect(await discovery.connect(_bleCandidate), same(ble.link));
    expect(await discovery.connect(fakeCandidate), same(usb.link));
  });

  test('a failing transport only hides its own devices', () async {
    usb.scanError = const FlukeTimeoutException('ID');
    expect(await discovery.scan(), [_bleCandidate]);

    ble.candidates = [];
    await expectLater(
      discovery.scan(),
      throwsA(const FlukeTimeoutException('ID')),
    );
  });

  test('device changes of all transports, dispose of all', () async {
    var changes = 0;
    final sub = discovery.onDevicesChanged.listen((_) => changes++);
    usb.changes.add(null);
    ble.changes.add(null);
    await pumpEventQueue();
    expect(changes, 2);
    await sub.cancel();

    discovery.dispose();
    expect(usb.disposed && ble.disposed, isTrue);
  });
}
