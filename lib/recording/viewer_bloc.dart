import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'recording.dart';
import 'recording_csv.dart';
import 'recording_files.dart';

sealed class RecordingViewerEvent extends Equatable {
  const RecordingViewerEvent();

  @override
  List<Object?> get props => [];
}

/// Shows an in-memory recording (just recorded or read from the meter),
/// not yet saved to a file.
final class RecordingViewerShown extends RecordingViewerEvent {
  const RecordingViewerShown(this.recording);

  final Recording recording;

  @override
  List<Object?> get props => [recording];
}

/// Asks the user for a CSV file and loads it.
final class RecordingViewerFileRequested extends RecordingViewerEvent {
  const RecordingViewerFileRequested();
}

final class RecordingViewerUnitSelected extends RecordingViewerEvent {
  const RecordingViewerUnitSelected(this.unit);

  final String unit;

  @override
  List<Object?> get props => [unit];
}

enum RecordingViewerStatus { empty, loading, loaded, failure }

final class RecordingViewerState extends Equatable {
  const RecordingViewerState({
    this.status = RecordingViewerStatus.empty,
    this.recording,
    this.fileName,
    this.selectedUnit,
    this.error,
    this.errorFile,
  });

  final RecordingViewerStatus status;
  final Recording? recording;

  /// File the recording was loaded from, `null` if it is not saved.
  final String? fileName;

  /// Base unit whose samples are charted.
  final String? selectedUnit;

  /// Last error opening or parsing a file.
  final Object? error;

  /// File the [error] refers to, `null` if the file could not be opened.
  final String? errorFile;

  List<RecordingSample> get selectedSamples =>
      recording?.samplesByUnit[selectedUnit] ?? const [];

  @override
  List<Object?> get props => [
    status,
    recording,
    fileName,
    selectedUnit,
    error,
    errorFile,
  ];
}

/// Holds the recording shown on the recording page. Independent of the
/// meter connection.
class RecordingViewerBloc
    extends Bloc<RecordingViewerEvent, RecordingViewerState> {
  RecordingViewerBloc({Future<PickedTextFile?> Function()? pickFile})
    : _pickFile = pickFile ?? pickCsvFile,
      super(const RecordingViewerState()) {
    on<RecordingViewerShown>(
      (event, emit) => emit(_loaded(event.recording, null)),
    );
    on<RecordingViewerFileRequested>(_onFileRequested);
    on<RecordingViewerUnitSelected>(
      (event, emit) => emit(
        RecordingViewerState(
          status: state.status,
          recording: state.recording,
          fileName: state.fileName,
          selectedUnit: event.unit,
        ),
      ),
    );
  }

  final Future<PickedTextFile?> Function() _pickFile;

  Future<void> _onFileRequested(
    RecordingViewerFileRequested event,
    Emitter<RecordingViewerState> emit,
  ) async {
    final previous = state;
    PickedTextFile? file;
    try {
      file = await _pickFile();
    } catch (e) {
      emit(_failure(previous, e));
      return;
    }
    if (file == null) return; // cancelled

    emit(
      RecordingViewerState(
        status: RecordingViewerStatus.loading,
        recording: previous.recording,
        fileName: file.name,
        selectedUnit: previous.selectedUnit,
      ),
    );
    try {
      emit(_loaded(recordingFromCsv(file.content), file.name));
    } catch (e) {
      emit(_failure(previous, e, file: file.name));
    }
  }

  static RecordingViewerState _loaded(Recording recording, String? fileName) {
    // Chart the unit with the most samples first.
    final groups = recording.samplesByUnit.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return RecordingViewerState(
      status: RecordingViewerStatus.loaded,
      recording: recording,
      fileName: fileName,
      selectedUnit: groups.isEmpty ? null : groups.first.key,
    );
  }

  /// Keeps a previously loaded recording visible next to the error.
  static RecordingViewerState _failure(
    RecordingViewerState previous,
    Object error, {
    String? file,
  }) => RecordingViewerState(
    status: previous.recording == null
        ? RecordingViewerStatus.failure
        : RecordingViewerStatus.loaded,
    recording: previous.recording,
    fileName: previous.fileName,
    selectedUnit: previous.selectedUnit,
    error: error,
    errorFile: file,
  );
}
