import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/usb/ftdi_serial.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('FlukeClient', () {
    test('sends command with CR and returns response after ACK', () async {
      final channel = FakeChannel()..respond('0\rFLUKE 289,V1.00,40211337\r');
      final client = FlukeClient(channel);
      final id = await client.identify();
      expect(channel.written, ['ID\r']);
      expect(id.serial, '40211337');
    });

    test('assembles a response split across reads', () async {
      final channel = FakeChannel()
        ..respond('0')
        ..respond('\rMV_AC,NONE,AUTO,VAC,50,-3,OFF,0.000,0,2,')
        ..respond('LIVE,0.007312,VAC,-3,3,5,NORMAL,NONE,1793196900.250,')
        ..respond('PRIMARY,0.007312,VAC,-3,3,5,NORMAL,NONE,1793196900.250\r');
      final r = await FlukeClient(channel).queryDisplay();
      expect(r.primary!.displayText, '7.312');
    });

    for (final (ack, text) in [
      ('1', 'syntax'),
      ('2', 'execution'),
      ('5', 'no data'),
    ]) {
      test('CMD_ACK $ack ($text) throws', () async {
        final channel = FakeChannel()..respond('$ack\r');
        await expectLater(
          FlukeClient(channel).command('QDDA'),
          throwsA(FlukeAckException('QDDA', ack)),
        );
      });
    }

    test('reads the stored properties, skipping unknown ones', () async {
      final channel = FakeChannel()
        ..respond("0\r'ACME Elektro'\r")
        ..respond("0\r'Max Muster'\r")
        ..respond('1\r')
        ..respond("0\r''\r");
      final properties = await FlukeClient(channel).readProperties();
      expect(channel.written, [
        'qmpq company\r',
        'qmpq operator\r',
        'qmpq site\r',
        'qmpq contact\r',
      ]);
      expect(
        properties,
        const MeterProperties(company: 'ACME Elektro', operator: 'Max Muster'),
      );
    });

    test('writes a property with mpq', () async {
      final channel = FakeChannel()..respond('0\r');
      await FlukeClient(channel).writeProperty('operator', 'Max Muster');
      expect(channel.written, ["mpq operator,'Max Muster'\r"]);
    });

    test('refuses texts the meter cannot take', () {
      final client = FlukeClient(FakeChannel());
      expect(
        () => client.writeProperty('operator', "O'Neil"),
        throwsArgumentError,
      );
      expect(
        () => client.writeProperty('operator', 'Müller'),
        throwsArgumentError,
      );
      expect(() => client.writeProperty('owner', 'x'), throwsArgumentError);
    });

    test('times out without answer', () async {
      await expectLater(
        FlukeClient(FakeChannel())
            .command('QDDA', timeout: const Duration(milliseconds: 50)),
        throwsA(isA<FlukeTimeoutException>()),
      );
    });
  });

  group('stripModemStatus', () {
    test('removes 2 status bytes per packet', () {
      final packet1 = [0x01, 0x60, ...List.filled(62, 0x41)];
      final packet2 = [0x01, 0x60, 0x42, 0x43];
      expect(stripModemStatus([...packet1, ...packet2], 64), [
        ...List.filled(62, 0x41),
        0x42,
        0x43,
      ]);
    });

    test('status-only packet yields no data', () {
      expect(stripModemStatus([0x01, 0x60], 64), isEmpty);
      expect(stripModemStatus([], 64), isEmpty);
    });
  });
}
