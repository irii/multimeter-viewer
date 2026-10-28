import 'dart:convert';
import 'dart:typed_data';

import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/fluke/fluke_memory_reader.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// Binary responses captured from a Fluke 289 by the dmm_util project
// (https://github.com/fvaleur/dmm_util, MIT, (c) 2011 Fredrik Valeur).
const _qrsiHex = '''
06 00 00 00 26 F9 D2 41 00 00 D4 30 26 F9 D2 41
00 B0 CB 33 00 20 8C 40 00 00 00 00 E1 7A A4 3F
7B 14 AE 47 07 00 00 00 02 00 00 00 01 00 00 00
01 00 02 00 00 00 14 40 00 00 00 00 00 00 01 00
00 00 00 00 00 00 00 00 20 00 00 00 01 00 02 00
D7 12 A2 3F 51 FC 18 73 02 00 00 00 04 00 05 00
02 00 00 00 26 F9 D2 41 00 B0 CB 33 42 61 74 74
65 72 79 20 31''';

const _qsrrHex = '''
26 F9 D2 41 00 00 D4 30 26 F9 D2 41 00 B0 CB 33
08 00 CE 88 A2 3F 7F FB 3A 70 02 00 00 00 04 00
05 00 02 00 00 00 26 F9 D2 41 00 10 01 31 07 00
4E D1 A1 3F A9 35 CD 3B 02 00 00 00 04 00 05 00
02 00 00 00 26 F9 D2 41 00 60 14 31 09 00 55 B0
10 40 1C 7C 61 32 02 00 00 00 04 00 05 00 02 00
00 00 26 F9 D2 41 00 00 D4 30 76 00 00 00 02 00
F2 1F A2 3F 72 8A 8E E4 02 00 00 00 04 00 05 00
02 00 00 00 26 F9 D2 41 00 00 D4 30 00 00 01 00
00 00''';

Uint8List hex(String s) => Uint8List.fromList([
  for (final b in s.split(RegExp(r'\s+')).where((b) => b.isNotEmpty))
    int.parse(b, radix: 16),
]);

final maps = MeterMaps({
  'primfunction': {0: 'LIMBO', 1: 'V_AC', 3: 'V_DC'},
  'secfunction': {0: 'NONE', 1: 'HERTZ'},
  'autorange': {0: 'MANUAL', 1: 'AUTO'},
  'unit': {0: 'NONE', 1: 'VDC', 2: 'VAC', 4: 'V'},
  'bolt': {0: 'OFF', 1: 'ON'},
  'mode': {0: 'NONE', 4: 'HOLD', 16: 'MIN_MAX_AVG', 32: 'RECORD'},
  'readingid': {
    1: 'LIVE',
    2: 'PRIMARY',
    7: 'MINIMUM',
    8: 'MAXIMUM',
    9: 'AVERAGE',
  },
  'state': {1: 'INVALID', 2: 'NORMAL', 5: 'OL'},
  'attribute': {0: 'NONE'},
  'recordtype': {0: 'INPUT', 1: 'INTERVAL'},
  'isstableflag': {0: 'UNSTABLE', 1: 'STABLE'},
  'transientstate': {0: 'NON_T'},
});

void main() {
  test('meter time is local wall-clock time', () {
    final t = meterTimeToDateTime(1273272515.3125);
    expect(t, DateTime(2010, 5, 7, 22, 48, 35, 312, 500));
    expect(t.isUtc, isFalse);
    expect(dateTimeToMeterTime(t), 1273272515.3125);
  });

  test('parses a recording header (qrsi)', () {
    final r = MemoryRecording.parse(0, hex(_qrsiHex), maps);
    expect(r.name, 'Battery 1');
    expect(r.startTime, DateTime(2010, 5, 7, 22, 48, 35, 312, 500));
    expect(r.endTime.second, 47);
    expect(r.sampleInterval, 900);
    expect(r.eventThreshold, closeTo(0.04, 1e-9));
    expect(r.readingIndex, 7);
    expect(r.sampleCount, 2);
    expect(r.primaryFunction, 'V_AC');
    expect(r.secondaryFunction, 'NONE');
    expect(r.range.autoRange, isTrue);
    expect(r.range.rangeNumber, 5);
    expect(r.range.baseUnit, 'VAC');
    expect(r.modes, ['RECORD']);
    expect(r.readings.single.id, 'PRIMARY');
    expect(r.readings.single.value, closeTo(0.0353, 1e-9));
    expect(MemoryRecording.minLength(hex(_qrsiHex)), 78 + 30);
  });

  test('parses a recording interval (qsrr) and fixes the average', () {
    final s = MemoryRecordingSample.parse(hex(_qsrrHex), maps);
    expect(s.duration, const Duration(milliseconds: 11800));
    expect(s.minimum!.value, closeTo(0.0348, 1e-9));
    expect(s.maximum!.value, closeTo(0.0362, 1e-9));
    // Raw AVERAGE is 4.1722 = sum over 118 ticks of 0.1 s.
    expect(s.average!.value, closeTo(4.1722 / 118, 1e-9));
    expect(s.primary.value, closeTo(0.0354, 1e-9));
    expect(s.primary.decimalPlaces, 4);
    expect(s.recordType, 'INPUT');
    expect(s.stable, isTrue);
    expect(s.transientState, 'NON_T');
  });

  test('converts a meter recording into an app recording', () {
    final info = MemoryRecording.parse(0, hex(_qrsiHex), maps);
    final sample = MemoryRecordingSample.parse(hex(_qsrrHex), maps);
    final r = memoryRecordingToRecording(info, [sample, sample]);
    expect(r.info.name, 'Battery 1');
    expect(r.startedAt, info.startTime);
    expect(r.systemStartedAt, isNull);
    expect(r.samples.first.elapsed, Duration.zero);
    expect(r.samples.first.trend, sample.average);
    expect(r.samples.first.systemTime, isNull);
  });

  test('qemap, qsls and quoted fields', () {
    expect(MeterMaps.parseMap(['2', '0', 'OFF', '1', 'ON']), {
      0: 'OFF',
      1: 'ON',
    });
    expect(
      () => MeterMaps.parseMap(['3', '0', 'OFF']),
      throwsA(isA<FlukeParseException>()),
    );
    expect(
      MemoryCounts.parse(['4', '3', '1', '9']),
      const MemoryCounts(recordings: 4, minMax: 3, peak: 1, measurements: 9),
    );
    expect(splitFields("'it''s, me',\"a,b\",x"), ["it's, me", 'a,b', 'x']);
    expect(maps.flags('mode', 4 | 32), ['HOLD', 'RECORD']);
    expect(maps.value('unit', 99), '#99');
  });

  group('FlukeClient binary responses', () {
    List<int> response(Uint8List payload) => [
      ...ascii.encode('0\r#0'),
      ...payload,
      0x0D,
    ];

    test('fixed length, split into chunks, with CR bytes inside', () async {
      // CR bytes inside and at the end of the data must not end the reply.
      final payload = Uint8List.fromList([
        for (var i = 0; i < MemoryRecordingSample.size; i++)
          i == 10 || i == 19 || i == MemoryRecordingSample.size - 1 ? 0x0D : i,
      ]);
      final bytes = response(payload);
      final channel = FakeChannel();
      for (var i = 0; i < bytes.length; i += 20) {
        channel.chunks.add(bytes.sublist(i, (i + 20).clamp(0, bytes.length)));
      }
      final result = await FlukeClient(channel)
          .binaryCommand('qsrr 7,0', length: MemoryRecordingSample.size);
      expect(result, payload);
      expect(channel.written, ['qsrr 7,0\r']);
    });

    test('variable length ends after header, readings and name', () async {
      final payload = hex(_qrsiHex);
      final bytes = response(payload);
      final channel = FakeChannel()
        ..chunks.add(bytes.sublist(0, 50))
        ..chunks.add(bytes.sublist(50, 120))
        ..chunks.add(bytes.sublist(120));
      final result = await FlukeClient(channel)
          .binaryCommand('qrsi 0', minLength: MemoryRecording.minLength);
      expect(result, payload);
    });

    test('repeats the command while the meter is busy', () async {
      final channel = FakeChannel()
        ..respond('8\r')
        ..respond('0\r4,3,1,9\r');
      expect(await FlukeClient(channel).textCommand('qsls'), [
        '4',
        '3',
        '1',
        '9',
      ]);
      expect(channel.written, ['qsls\r', 'qsls\r']);
    });

    test('commands run one after another', () async {
      final channel = FakeChannel()
        ..respond('0\rFLUKE 289,V1.00,1\r')
        ..respond('0\r4,3,1,9\r');
      final client = FlukeClient(channel);
      final results = await Future.wait([
        client.command('ID'),
        client.command('qsls'),
      ]);
      expect(results, ['FLUKE 289,V1.00,1', '4,3,1,9']);
    });
  });
}
