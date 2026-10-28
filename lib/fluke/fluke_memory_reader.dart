import 'package:equatable/equatable.dart';

import '../recording/recording.dart';
import 'fluke_client.dart';
import 'fluke_memory.dart';
import 'qdda.dart';

export 'fluke_memory.dart';

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

/// [MeterMemory] over a [FlukeClient].
class FlukeMemoryReader implements MeterMemory {
  FlukeMemoryReader(this._client);

  final FlukeClient _client;
  MeterMaps? _maps;

  /// The value maps are fixed per firmware, so they are read once.
  Future<MeterMaps> _loadMaps() async => _maps ??= MeterMaps({
    for (final name in MeterMaps.names)
      name: MeterMaps.parseMap(await _client.textCommand('qemap $name')),
  });

  @override
  Future<MemoryContents> readContents() async {
    final maps = await _loadMaps();
    final counts = MemoryCounts.parse(await _client.textCommand('qsls'));
    return MemoryContents(
      recordings: [
        for (var i = 0; i < counts.recordings; i++)
          MemoryRecording.parse(
            i,
            await _client.binaryCommand(
              'qrsi $i',
              minLength: MemoryRecording.minLength,
            ),
            maps,
          ),
      ],
      minMaxSessions: [
        for (var i = 0; i < counts.minMax; i++)
          MemorySession.parse(
            MemorySessionKind.minMax,
            i,
            await _client.binaryCommand(
              'qmmsi $i',
              minLength: MemorySession.minLength,
            ),
            maps,
          ),
      ],
      peakSessions: [
        for (var i = 0; i < counts.peak; i++)
          MemorySession.parse(
            MemorySessionKind.peak,
            i,
            await _client.binaryCommand(
              'qpsi $i',
              minLength: MemorySession.minLength,
            ),
            maps,
          ),
      ],
      measurements: [
        for (var i = 0; i < counts.measurements; i++)
          MemoryMeasurement.parse(
            i,
            await _client.binaryCommand(
              'qsmr $i',
              minLength: MemoryMeasurement.minLength,
            ),
            maps,
          ),
      ],
    );
  }

  @override
  Future<Recording> downloadRecording(
    MemoryRecording recording, {
    MeterIdentity? identity,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final maps = await _loadMaps();
    final total = recording.sampleCount;
    final samples = <MemoryRecordingSample>[];
    onProgress?.call(0, total);
    for (var i = 0; i < total; i++) {
      if (isCancelled?.call() ?? false) throw const MemoryDownloadCancelled();
      samples.add(
        MemoryRecordingSample.parse(
          await _client.binaryCommand(
            'qsrr ${recording.readingIndex},$i',
            length: MemoryRecordingSample.size,
          ),
          maps,
        ),
      );
      onProgress?.call(i + 1, total);
    }
    return memoryRecordingToRecording(recording, samples, identity: identity);
  }
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
