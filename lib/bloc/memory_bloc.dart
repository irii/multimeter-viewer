import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../fluke/fluke_memory_reader.dart';
import '../fluke/qdda.dart';
import '../recording/recording.dart';

sealed class MemoryEvent extends Equatable {
  const MemoryEvent();

  @override
  List<Object?> get props => [];
}

/// (Re-)reads the list of everything stored in the meter.
final class MemoryLoadRequested extends MemoryEvent {
  const MemoryLoadRequested();
}

/// Downloads all samples of [recording].
final class MemoryDownloadRequested extends MemoryEvent {
  const MemoryDownloadRequested(this.recording);

  final MemoryRecording recording;

  @override
  List<Object?> get props => [recording];
}

final class MemoryDownloadCancelRequested extends MemoryEvent {
  const MemoryDownloadCancelRequested();
}

enum MemoryStatus { loading, loaded, failure }

final class MemoryState extends Equatable {
  const MemoryState({
    this.status = MemoryStatus.loading,
    this.contents = const MemoryContents(),
    this.error,
    this.downloading,
    this.downloadDone = 0,
    this.downloadTotal = 0,
    this.downloaded,
    this.downloadCount = 0,
    this.downloadError,
    this.downloadCancelled = false,
  });

  final MemoryStatus status;
  final MemoryContents contents;

  /// Why reading the memory failed.
  final Object? error;

  /// Recording being downloaded, with progress.
  final MemoryRecording? downloading;
  final int downloadDone;
  final int downloadTotal;

  /// Last completed download; [downloadCount] changes with every new one.
  final Recording? downloaded;
  final int downloadCount;

  /// Why the last download failed (not set when cancelled).
  final Object? downloadError;
  final bool downloadCancelled;

  double? get progress =>
      downloadTotal == 0 ? null : downloadDone / downloadTotal;

  MemoryState copyWith({
    MemoryStatus? status,
    MemoryContents? contents,
    Object? Function()? error,
    MemoryRecording? Function()? downloading,
    int? downloadDone,
    int? downloadTotal,
    Recording? downloaded,
    int? downloadCount,
    Object? Function()? downloadError,
    bool? downloadCancelled,
  }) => MemoryState(
    status: status ?? this.status,
    contents: contents ?? this.contents,
    error: error != null ? error() : this.error,
    downloading: downloading != null ? downloading() : this.downloading,
    downloadDone: downloadDone ?? this.downloadDone,
    downloadTotal: downloadTotal ?? this.downloadTotal,
    downloaded: downloaded ?? this.downloaded,
    downloadCount: downloadCount ?? this.downloadCount,
    downloadError: downloadError != null ? downloadError() : this.downloadError,
    downloadCancelled: downloadCancelled ?? this.downloadCancelled,
  );

  @override
  List<Object?> get props => [
    status,
    contents,
    error,
    downloading,
    downloadDone,
    downloadTotal,
    downloadCount,
    downloadError,
    downloadCancelled,
  ];
}

/// Lists and downloads what is stored in the meter's memory. Lives as long as
/// the memory page is shown.
class MemoryBloc extends Bloc<MemoryEvent, MemoryState> {
  MemoryBloc({required this.memory, this.identity})
    : super(const MemoryState()) {
    on<MemoryLoadRequested>(_onLoad, transformer: droppable());
    on<MemoryDownloadRequested>(_onDownload, transformer: droppable());
    on<MemoryDownloadCancelRequested>((_, _) => _cancelRequested = true);
  }

  final MeterMemory memory;

  /// Meter the downloaded recordings are attributed to.
  final MeterIdentity? identity;
  bool _cancelRequested = false;

  Future<void> _onLoad(
    MemoryLoadRequested event,
    Emitter<MemoryState> emit,
  ) async {
    emit(state.copyWith(status: MemoryStatus.loading, error: () => null));
    try {
      final contents = await memory.readContents();
      emit(state.copyWith(status: MemoryStatus.loaded, contents: contents));
    } catch (e) {
      emit(state.copyWith(status: MemoryStatus.failure, error: () => e));
    }
  }

  Future<void> _onDownload(
    MemoryDownloadRequested event,
    Emitter<MemoryState> emit,
  ) async {
    _cancelRequested = false;
    emit(
      state.copyWith(
        downloading: () => event.recording,
        downloadDone: 0,
        downloadTotal: event.recording.sampleCount,
        downloadError: () => null,
        downloadCancelled: false,
      ),
    );
    try {
      final recording = await memory.downloadRecording(
        event.recording,
        identity: identity,
        isCancelled: () => _cancelRequested || isClosed,
        onProgress: (done, total) {
          if (!isClosed) {
            emit(state.copyWith(downloadDone: done, downloadTotal: total));
          }
        },
      );
      emit(
        state.copyWith(
          downloading: () => null,
          downloaded: recording,
          downloadCount: state.downloadCount + 1,
        ),
      );
    } on MemoryDownloadCancelled {
      emit(state.copyWith(downloading: () => null, downloadCancelled: true));
    } catch (e) {
      emit(state.copyWith(downloading: () => null, downloadError: () => e));
    }
  }
}
