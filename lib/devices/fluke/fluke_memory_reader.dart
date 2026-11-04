import '../../meter/meter_memory.dart';
import '../../meter/model/meter_identity.dart';
import '../../recording/recording.dart';
import 'fluke_client.dart';
import 'fluke_memory.dart';

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
          parseMemoryRecording(
            i,
            await _client.binaryCommand(
              'qrsi $i',
              minLength: memoryRecordingMinLength,
            ),
            maps,
          ),
      ],
      minMaxSessions: [
        for (var i = 0; i < counts.minMax; i++)
          parseMemorySession(
            MemorySessionKind.minMax,
            i,
            await _client.binaryCommand(
              'qmmsi $i',
              minLength: memorySessionMinLength,
            ),
            maps,
          ),
      ],
      peakSessions: [
        for (var i = 0; i < counts.peak; i++)
          parseMemorySession(
            MemorySessionKind.peak,
            i,
            await _client.binaryCommand(
              'qpsi $i',
              minLength: memorySessionMinLength,
            ),
            maps,
          ),
      ],
      measurements: [
        for (var i = 0; i < counts.measurements; i++)
          parseMemoryMeasurement(
            i,
            await _client.binaryCommand(
              'qsmr $i',
              minLength: memoryMeasurementMinLength,
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
        parseMemoryRecordingSample(
          await _client.binaryCommand(
            'qsrr ${recording.readingIndex},$i',
            length: memoryRecordingSampleSize,
          ),
          maps,
        ),
      );
      onProgress?.call(i + 1, total);
    }
    return memoryRecordingToRecording(recording, samples, identity: identity);
  }
}
