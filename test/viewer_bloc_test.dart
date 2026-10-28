import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/recording/recording_csv.dart';
import 'package:multimeter_viewer/recording/viewer_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_csv_test.dart' show sampleRecording;

void main() {
  blocTest<RecordingViewerBloc, RecordingViewerState>(
    'loads a picked CSV file',
    build: () => RecordingViewerBloc(
      pickFile: () async =>
          (name: 'motor.csv', content: recordingToCsv(sampleRecording())),
    ),
    act: (bloc) => bloc.add(const RecordingViewerFileRequested()),
    skip: 1,
    verify: (bloc) {
      expect(bloc.state.status, RecordingViewerStatus.loaded);
      expect(bloc.state.fileName, 'motor.csv');
      expect(bloc.state.recording!.identity?.serial, '40211337');
      expect(bloc.state.selectedUnit, 'VAC');
      expect(bloc.state.selectedSamples, hasLength(2));
    },
  );

  blocTest<RecordingViewerBloc, RecordingViewerState>(
    'cancelled picker changes nothing',
    build: () => RecordingViewerBloc(pickFile: () async => null),
    act: (bloc) => bloc.add(const RecordingViewerFileRequested()),
    expect: () => <RecordingViewerState>[],
  );

  blocTest<RecordingViewerBloc, RecordingViewerState>(
    'invalid file fails but keeps a loaded recording',
    build: () => RecordingViewerBloc(
      pickFile: () async => (name: 'kaputt.csv', content: 'foo'),
    ),
    seed: () => RecordingViewerState(
      status: RecordingViewerStatus.loaded,
      recording: sampleRecording(),
      selectedUnit: 'VAC',
    ),
    act: (bloc) => bloc.add(const RecordingViewerFileRequested()),
    verify: (bloc) {
      expect(bloc.state.status, RecordingViewerStatus.loaded);
      expect(bloc.state.recording, sampleRecording());
      expect(bloc.state.error, isA<RecordingFormatException>());
      expect(bloc.state.errorFile, 'kaputt.csv');
    },
  );

  blocTest<RecordingViewerBloc, RecordingViewerState>(
    'invalid file without previous recording is a failure',
    build: () => RecordingViewerBloc(
      pickFile: () async => (name: 'kaputt.csv', content: 'foo'),
    ),
    act: (bloc) => bloc.add(const RecordingViewerFileRequested()),
    verify: (bloc) => expect(bloc.state.status, RecordingViewerStatus.failure),
  );

  blocTest<RecordingViewerBloc, RecordingViewerState>(
    'shows an in-memory recording',
    build: RecordingViewerBloc.new,
    act: (bloc) => bloc.add(RecordingViewerShown(sampleRecording())),
    verify: (bloc) {
      expect(bloc.state.status, RecordingViewerStatus.loaded);
      expect(bloc.state.fileName, isNull);
    },
  );
}
