part of 'recording_bloc.dart';

enum RecordingStatus { idle, recording, finished }

final class RecordingState extends Equatable {
  const RecordingState({
    this.status = RecordingStatus.idle,
    this.info,
    this.identity,
    this.startedAt,
    this.meterStartedAt,
    this.elapsed = Duration.zero,
    this.samples = const [],
    this.stopReason,
  });

  final RecordingStatus status;
  final RecordingInfo? info;
  final MeterIdentity? identity;

  /// System time the recording was started.
  final DateTime? startedAt;

  /// meter time of the first sample.
  final DateTime? meterStartedAt;

  /// Time since start by the system clock (drives progress and auto-stop,
  /// also while the meter's clock is frozen by HOLD).
  final Duration elapsed;

  /// Grows during a recording; compared by length only (see [props]).
  final List<RecordingSample> samples;

  /// Why the recording ended before its planned duration, if it did.
  final RecordingStopReason? stopReason;

  double get progress {
    final total = info?.duration.inMilliseconds ?? 0;
    if (total == 0) return 0;
    return (elapsed.inMilliseconds / total).clamp(0, 1).toDouble();
  }

  /// The recording so far (complete once [status] is finished).
  Recording toRecording() => Recording(
    info: info!,
    startedAt: meterStartedAt ?? startedAt!,
    systemStartedAt: startedAt,
    duration: elapsed,
    samples: samples,
    identity: identity,
    stopReason: stopReason,
    sampleInterval: _meanInterval,
  );

  /// Mean time between samples by the meter clock.
  Duration? get _meanInterval => samples.length < 2
      ? null
      : (samples.last.elapsed - samples.first.elapsed) ~/ (samples.length - 1);

  RecordingState copyWith({
    RecordingStatus? status,
    MeterIdentity? identity,
    DateTime? meterStartedAt,
    Duration? elapsed,
    List<RecordingSample>? samples,
    RecordingStopReason? Function()? stopReason,
  }) => RecordingState(
    status: status ?? this.status,
    info: info,
    identity: identity ?? this.identity,
    startedAt: startedAt,
    meterStartedAt: meterStartedAt ?? this.meterStartedAt,
    elapsed: elapsed ?? this.elapsed,
    samples: samples ?? this.samples,
    stopReason: stopReason != null ? stopReason() : this.stopReason,
  );

  @override
  List<Object?> get props => [
    status,
    info,
    identity,
    startedAt,
    meterStartedAt,
    elapsed,
    samples.length,
    stopReason,
  ];
}
