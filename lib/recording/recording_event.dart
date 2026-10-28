part of 'recording_bloc.dart';

sealed class RecordingEvent extends Equatable {
  const RecordingEvent();

  @override
  List<Object?> get props => [];
}

final class RecordingStartRequested extends RecordingEvent {
  const RecordingStartRequested(this.info);

  final RecordingInfo info;

  @override
  List<Object?> get props => [info];
}

final class RecordingStopRequested extends RecordingEvent {
  const RecordingStopRequested();
}

/// Drops a finished recording (after saving or when not wanted).
final class RecordingDiscarded extends RecordingEvent {
  const RecordingDiscarded();
}

final class _RecordingMeterUpdated extends RecordingEvent {
  const _RecordingMeterUpdated(this.meterState);

  final MeterState meterState;

  @override
  List<Object?> get props => [meterState];
}

final class _RecordingTicked extends RecordingEvent {
  const _RecordingTicked();
}
