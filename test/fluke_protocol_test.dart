import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/devices/fluke/fluke_client.dart';
import 'package:multimeter_viewer/devices/fluke/fluke_protocol.dart';
import 'package:multimeter_viewer/meter/model/model.dart';

import 'fakes.dart';

const _timeout = Duration(milliseconds: 50);

void main() {
  const protocol = FlukeProtocol();

  test('probe reads the identity and the owner texts', () async {
    final channel = FakeChannel()
      ..respond('0\rFLUKE 289,V1.00,40211337\r')
      ..respond("0\r'ACME'\r")
      ..respond("0\r'Max'\r")
      ..respond("0\r''\r")
      ..respond("0\r''\r");

    final probe = await protocol.probe(channel, timeout: _timeout);

    expect(probe.identity.model, 'FLUKE 289');
    expect(probe.properties?.company, 'ACME');
    expect(probe.properties?.operator, 'Max');
    expect(channel.written.first, 'ID\r');
    expect(channel.closed, isFalse, reason: 'the caller closes it');
  });

  test('a device that does not answer is no meter', () {
    expect(
      protocol.probe(FakeChannel(), timeout: _timeout),
      throwsA(const MeterTimeoutException('ID')),
    );
  });

  test('a device with another identity is no meter', () {
    final channel = FakeChannel()..respond('0\rSOMETHING,1,2\r');
    expect(
      protocol.probe(channel, timeout: _timeout),
      throwsA(isA<MeterParseException>()),
    );
  });

  test('attaching gives a link that closes its channel', () async {
    final channel = FakeChannel();
    final link = protocol.attach(channel);
    expect(link, isA<FlukeClient>());
    await link.close();
    expect(channel.closed, isTrue);
  });
}
