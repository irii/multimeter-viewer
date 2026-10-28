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
