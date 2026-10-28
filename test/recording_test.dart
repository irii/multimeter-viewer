import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/bloc/meter_bloc.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:multimeter_viewer/recording/recording_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

QddaResponse displayAt(double t, {double value = 0.007312}) =>
    QddaResponse.parse(
      'MV_AC,NONE,AUTO,VAC,50,-3,OFF,0.000,0,2,'
      'LIVE,$value,VAC,-3,3,5,NORMAL,NONE,$t,'
      'PRIMARY,$value,VAC,-3,3,5,NORMAL,NONE,$t',
    );

MeterState connected(QddaResponse display, {DateTime? receivedAt}) =>
    MeterState(
      status: MeterStatus.connected,
      identity: FakeLink.identity,
      display: display,
      receivedAt: receivedAt,
    );

const info = RecordingInfo(
  name: 'Motor A',
  identifier: 'K-4711',
  comment: 'Anlauf, Phase "L1"',
  duration: Duration(seconds: 10),
);

void main() {
  late StreamController<MeterState> meter;
  late DateTime now;

  setUp(() {
    meter = StreamController<MeterState>();
    now = DateTime(2026, 10, 28, 14, 5);
  });

  RecordingBloc build() => RecordingBloc(
    meterStates: meter.stream,
    clock: () => now,
    tickInterval: const Duration(hours: 1),
  );

  Future<void> feed(MeterState s) async {
    meter.add(s);
    await Future<void>.delayed(Duration.zero);
  }

  blocTest<RecordingBloc, RecordingState>(
    'records new readings and skips frozen timestamps',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordingStartRequested(info));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 1));
      await feed(connected(displayAt(100)));
      await feed(connected(displayAt(100))); // HOLD
      now = now.add(const Duration(seconds: 1));
      await feed(connected(displayAt(101)));
    },
    verify: (bloc) {
      expect(bloc.state.status, RecordingStatus.recording);
      expect(bloc.state.samples, hasLength(2));
      // Elapsed time follows the meter clock (100 s -> 101 s).
      expect(bloc.state.samples.last.elapsed, const Duration(seconds: 1));
      expect(bloc.state.identity, FakeLink.identity);
    },
  );

  blocTest<RecordingBloc, RecordingState>(
    'finishes after the planned duration',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordingStartRequested(info));
      await Future<void>.delayed(Duration.zero);
      await feed(connected(displayAt(100)));
      now = now.add(const Duration(seconds: 11));
      await feed(connected(displayAt(111)));
    },
    verify: (bloc) {
      expect(bloc.state.status, RecordingStatus.finished);
      expect(bloc.state.samples, hasLength(1));
      expect(bloc.state.elapsed, info.duration);
      expect(bloc.state.stopReason, isNull);
    },
  );

  blocTest<RecordingBloc, RecordingState>(
    'disconnect ends the recording',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordingStartRequested(info));
      await Future<void>.delayed(Duration.zero);
      await feed(connected(displayAt(100)));
      await feed(const MeterState());
    },
    verify: (bloc) {
      expect(bloc.state.status, RecordingStatus.finished);
      expect(bloc.state.stopReason, RecordingStopReason.disconnected);
    },
  );

  blocTest<RecordingBloc, RecordingState>(
    'stop and discard',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordingStartRequested(info));
      bloc.add(const RecordingStopRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, RecordingStatus.finished);
      bloc.add(const RecordingDiscarded());
    },
    verify: (bloc) => expect(bloc.state, const RecordingState()),
  );

  blocTest<RecordingBloc, RecordingState>(
    'uses the Fluke clock as time base and keeps the system time',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordingStartRequested(info));
      await Future<void>.delayed(Duration.zero);
      // System clock runs 5 s per sample, meter clock 0.5 s.
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 5));
        await feed(connected(displayAt(1000 + i * 0.5), receivedAt: now));
      }
    },
    verify: (bloc) {
      final samples = bloc.state.samples;
      expect(samples.map((s) => s.elapsed), const [
        Duration.zero,
        Duration(milliseconds: 500),
        Duration(seconds: 1),
      ]);
      expect(samples.last.systemTime, DateTime(2026, 10, 28, 14, 5, 15));
      final recording = bloc.state.toRecording();
      expect(recording.startedAt, meterTimeToDateTime(1000));
      expect(recording.systemStartedAt, DateTime(2026, 10, 28, 14, 5));
    },
  );
}
