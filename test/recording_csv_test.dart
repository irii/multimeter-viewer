import 'package:multimeter_viewer/about/app_info.dart';
import 'package:multimeter_viewer/fluke/fluke_memory_reader.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:multimeter_viewer/recording/recording.dart';
import 'package:multimeter_viewer/recording/recording_csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'recording_test.dart' show displayAt;

Recording sampleRecording() => Recording(
  info: const RecordingInfo(
    name: 'Motor A',
    identifier: 'K-4711',
    comment: 'Anlauf, Phase "L1"\nzweite Zeile',
    duration: Duration(seconds: 10),
  ),
  startedAt: DateTime.utc(2026, 10, 28, 13, 5).toLocal(),
  systemStartedAt: DateTime.utc(2026, 10, 28, 13, 5, 2).toLocal(),
  duration: const Duration(milliseconds: 1500),
  identity: FakeLink.identity,
  stopReason: RecordingStopReason.stopped,
  samples: [
    RecordingSample.fromDisplay(
      displayAt(100),
      Duration.zero,
      systemTime: DateTime.utc(1970, 1, 1, 0, 1, 42, 300).toLocal(),
    ),
    RecordingSample.fromDisplay(
      systemTime: DateTime.utc(1970, 1, 1, 0, 1, 43, 800).toLocal(),
      QddaResponse.parse(
        'MV_AC,NONE,AUTO,VAC,50,-3,OFF,0.000,1,HOLD,2,'
        'LIVE,9.99999999E+37,VAC,-3,3,5,OL,NONE,101.5,'
        'PRIMARY,9.99999999E+37,VAC,-3,3,5,OL,NONE,101.5',
      ),
      const Duration(milliseconds: 1500),
    ),
  ],
);

void main() {
  test('CSV contains meter model, serial and firmware', () {
    final lines = recordingToCsv(sampleRecording()).trim().split('\n');
    expect(lines, contains('# App: Multimeter Viewer'));
    expect(lines, contains('# App version: ${AppInfo.version}'));
    expect(lines, contains('# Name: Motor A'));
    expect(lines, contains('# Identifier: K-4711'));
    expect(lines, contains(r'# Comment: Anlauf, Phase "L1"\nzweite Zeile'));
    expect(lines, contains('# Model: FLUKE 289'));
    expect(lines, contains('# Serial number: 40211337'));
    expect(lines, contains('# Firmware: V1.00'));
    expect(lines, contains('# Start: 2026-10-28T13:05:00.000Z'));
    expect(lines.where((l) => !l.startsWith('#')), hasLength(3));
    final header = lines.firstWhere((l) => !l.startsWith('#')).split(',');
    expect(header.take(5), [
      'time',
      'local_time',
      'system_time',
      'system_local_time',
      'seconds',
    ]);
    expect(lines, contains('# System start: 2026-10-28T13:05:02.000Z'));
    // Local wall-clock time of the first sample (meter timestamp 100 s).
    // meter time 100 s = 1970-01-01 00:01:40 on the meter's clock.
    final local = meterTimeToDateTime(100);
    String two(int v) => v.toString().padLeft(2, '0');
    expect(
      lines[lines.indexOf(lines.firstWhere((l) => l.startsWith('time'))) + 1],
      contains(
        '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.000',
      ),
    );
  });

  test('CSV round trip keeps metadata and samples', () {
    final original = sampleRecording();
    final loaded = recordingFromCsv(recordingToCsv(original));

    expect(loaded.info, original.info);
    expect(loaded.identity, original.identity);
    expect(loaded.startedAt, original.startedAt);
    expect(loaded.systemStartedAt, original.systemStartedAt);
    expect(
      loaded.samples.map((s) => s.systemTime),
      original.samples.map((s) => s.systemTime),
    );
    expect(loaded.duration, original.duration);
    expect(loaded.stopReason, original.stopReason);
    expect(loaded.samples, hasLength(2));

    final first = loaded.samples.first;
    expect(first.primaryFunction, 'MV_AC');
    expect(first.primary.value, 0.007312);
    expect(first.primary.baseUnit, 'VAC');
    expect(first.primary.multiplier, -3);
    expect(first.primary.displayText, '7.312');
    expect(first.primary.timestamp, 100);

    final second = loaded.samples.last;
    expect(second.primary.state, 'OL');
    expect(second.primary.hasValue, isFalse);
    expect(second.modes, ['HOLD']);
    expect(second.elapsed, const Duration(milliseconds: 1500));
  });

  test('rejects files without the sample table', () {
    expect(
      () => recordingFromCsv('# Name: x\n'),
      throwsA(isA<RecordingFormatException>()),
    );
    expect(
      () => recordingFromCsv('foo,bar\n1,2\n'),
      throwsA(isA<RecordingFormatException>()),
    );
  });

  test('groups samples by unit', () {
    final r = sampleRecording();
    expect(r.samplesByUnit.keys, ['VAC']);
  });

  test('suggested file name', () {
    expect(
      suggestedFileName(sampleRecording().info, DateTime(2026, 10, 28, 14, 5)),
      'Motor_A_2026-10-28_1405.csv',
    );
  });

  test('files without system time load without it', () {
    final csv = recordingToCsv(sampleRecording())
        .split('\n')
        .where((l) => !l.startsWith('# System start'))
        .map((l) {
          if (l.startsWith('#') || l.isEmpty) return l;
          final f = l.split(',');
          f.removeRange(2, 4); // drop system_time, system_local_time
          return f.join(',');
        })
        .join('\n');
    final loaded = recordingFromCsv(csv);
    expect(loaded.systemStartedAt, isNull);
    expect(loaded.samples.first.systemTime, isNull);
  });

  test('meter recordings keep their metadata through CSV', () {
    Reading reading(String id, double value) => Reading(
      id: id,
      value: value,
      baseUnit: 'VDC',
      multiplier: 0,
      decimalPlaces: 3,
      displayDigits: 5,
      state: 'NORMAL',
      attribute: 'NONE',
      timestamp: 1000,
    );
    const range = RangeData(
      autoRange: false,
      baseUnit: 'VDC',
      rangeNumber: 50,
      multiplier: 0,
    );
    final memory = MemoryRecording(
      index: 0,
      name: 'Trend 1',
      start: 1000,
      end: 1060,
      sampleInterval: 30,
      eventThreshold: 0.04,
      readingIndex: 7,
      sampleCount: 2,
      primaryFunction: 'V_DC',
      secondaryFunction: 'NONE',
      range: range,
      modes: const ['RECORD'],
      readings: const [],
    );
    final recording = memoryRecordingToRecording(memory, [
      for (final (start, type) in [(1000.0, 'INTERVAL'), (1030.0, 'INPUT')])
        MemoryRecordingSample(
          start: start,
          end: start + 30,
          primary: reading('PRIMARY', 12),
          minimum: reading('MINIMUM', 11),
          maximum: reading('MAXIMUM', 13),
          average: reading('AVERAGE', 12.1),
          duration: const Duration(seconds: 30),
          recordType: type,
          stable: type == 'INTERVAL',
          transientState: 'NON_T',
        ),
    ], identity: FakeLink.identity);

    final csv = recordingToCsv(recording);
    expect(csv, contains('# Source: meter'));
    expect(csv, contains('# Interval (s): 30.000'));
    expect(csv, contains('# Event threshold (%): 4'));

    final loaded = recordingFromCsv(csv);
    expect(loaded.origin, RecordingOrigin.meter);
    expect(loaded.sampleInterval, const Duration(seconds: 30));
    expect(loaded.eventThreshold, closeTo(0.04, 1e-9));
    expect(loaded.range, range);
    expect(loaded.samples.map((s) => s.recordType), ['INTERVAL', 'INPUT']);
    expect(loaded.samples.map((s) => s.stable), [true, false]);
    expect(loaded.samples.first.transientState, 'NON_T');
    expect(loaded.samples.first.secondaryFunction, 'NONE');
    expect(loaded.samples.first.average!.value, 12.1);
  });

  test('app recordings store range, secondary function and interval', () {
    final loaded = recordingFromCsv(recordingToCsv(sampleRecording()));
    expect(loaded.origin, RecordingOrigin.app);
    expect(loaded.samples.first.range?.rangeNumber, 50);
    expect(loaded.samples.first.secondaryFunction, 'NONE');
    expect(loaded.samples.first.recordType, isNull);
  });
}
