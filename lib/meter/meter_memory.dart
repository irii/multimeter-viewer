import 'package:equatable/equatable.dart';

import '../recording/recording.dart';
import 'model/memory_items.dart';
import 'model/meter_identity.dart';

export 'model/memory_items.dart';

/// Everything stored in the meter's memory.
class MemoryContents extends Equatable {
  const MemoryContents({
    this.recordings = const [],
    this.minMaxSessions = const [],
    this.peakSessions = const [],
    this.measurements = const [],
  });

  final List<MemoryRecording> recordings;
  final List<MemorySession> minMaxSessions;
  final List<MemorySession> peakSessions;
  final List<MemoryMeasurement> measurements;

  bool get isEmpty =>
      recordings.isEmpty &&
      minMaxSessions.isEmpty &&
      peakSessions.isEmpty &&
      measurements.isEmpty;

  @override
  List<Object?> get props => [
    recordings,
    minMaxSessions,
    peakSessions,
    measurements,
  ];
}

/// Thrown when a download is cancelled via its `isCancelled` callback.
class MemoryDownloadCancelled implements Exception {
  const MemoryDownloadCancelled();

  @override
  String toString() => 'MemoryDownloadCancelled';
}

/// Reads the meter's memory.
abstract interface class MeterMemory {
  /// Lists all saved recordings, sessions and measurements (without the
  /// samples of the recordings).
  Future<MemoryContents> readContents();

  /// Downloads all samples of [recording] (one request per sample).
  Future<Recording> downloadRecording(
    MemoryRecording recording, {
    MeterIdentity? identity,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  });
}

/// Converts a recording read from the meter into the app's [Recording], so it
/// can be shown and saved like a live recording.
Recording memoryRecordingToRecording(
  MemoryRecording recording,
  List<MemoryRecordingSample> samples, {
  MeterIdentity? identity,
}) => Recording(
  info: RecordingInfo(
    name: recording.name,
    identifier: '',
    comment: '',
    duration: recording.duration,
  ),
  startedAt: recording.startTime,
  duration: recording.duration,
  identity: identity,
  origin: RecordingOrigin.meter,
  sampleInterval: Duration(
    microseconds: (recording.sampleInterval * 1e6).round(),
  ),
  eventThreshold: recording.eventThreshold,
  samples: [
    for (final s in samples)
      RecordingSample(
        elapsed: Duration(
          microseconds: ((s.start - recording.start) * 1e6).round(),
        ),
        primaryFunction: recording.primaryFunction,
        primary: s.primary,
        minimum: s.minimum,
        maximum: s.maximum,
        average: s.average,
        interval: s.duration,
        secondaryFunction: recording.secondaryFunction,
        range: recording.range,
        modes: recording.modes,
        recordType: s.recordType,
        stable: s.stable,
        transientState: s.transientState,
      ),
  ],
);
