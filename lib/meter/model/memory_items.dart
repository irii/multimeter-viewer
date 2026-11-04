import 'package:equatable/equatable.dart';

import 'meter_display.dart';

/// A recording stored in the meter.
class MemoryRecording extends Equatable {
  const MemoryRecording({
    required this.index,
    required this.name,
    required this.start,
    required this.end,
    required this.sampleInterval,
    required this.eventThreshold,
    required this.readingIndex,
    required this.sampleCount,
    required this.primaryFunction,
    required this.secondaryFunction,
    required this.range,
    required this.modes,
    required this.readings,
  });

  /// Position in the meter's recording list.
  final int index;
  final String name;

  /// meter timestamps (see [meterTimeToDateTime]).
  final double start;
  final double end;

  /// Seconds between samples.
  final double sampleInterval;

  /// Relative change that triggers an extra sample (e.g. 0.04 = 4 %).
  final double eventThreshold;

  /// Key for reading the samples of this recording from the meter.
  final int readingIndex;
  final int sampleCount;
  final String primaryFunction;
  final String secondaryFunction;
  final RangeData range;
  final List<String> modes;

  /// Summary readings of the whole recording (e.g. the last PRIMARY).
  final List<Reading> readings;

  DateTime get startTime => meterTimeToDateTime(start);

  DateTime get endTime => meterTimeToDateTime(end);

  Duration get duration =>
      Duration(microseconds: ((end - start) * 1e6).round());

  @override
  List<Object?> get props => [
    index,
    name,
    start,
    end,
    sampleInterval,
    eventThreshold,
    readingIndex,
    sampleCount,
    primaryFunction,
    secondaryFunction,
    range,
    modes,
    readings,
  ];
}

/// One interval of a recording.
class MemoryRecordingSample extends Equatable {
  const MemoryRecordingSample({
    required this.start,
    required this.end,
    required this.primary,
    required this.minimum,
    required this.maximum,
    required this.average,
    required this.duration,
    required this.recordType,
    required this.stable,
    required this.transientState,
  });

  /// meter timestamps of the interval.
  final double start;
  final double end;

  /// Reading at the start of the interval.
  final Reading primary;
  final Reading? minimum;
  final Reading? maximum;

  /// Mean over the interval.
  final Reading? average;
  final Duration duration;

  /// `INTERVAL` (regular sample) or `INPUT` (triggered by a change).
  final String recordType;
  final bool stable;
  final String transientState;

  @override
  List<Object?> get props => [
    start,
    end,
    primary,
    minimum,
    maximum,
    average,
    duration,
    recordType,
    stable,
    transientState,
  ];
}

enum MemorySessionKind { minMax, peak }

/// A saved min/max or peak session.
class MemorySession extends Equatable {
  const MemorySession({
    required this.kind,
    required this.index,
    required this.name,
    required this.start,
    required this.end,
    required this.primaryFunction,
    required this.secondaryFunction,
    required this.range,
    required this.modes,
    required this.readings,
  });

  final MemorySessionKind kind;
  final int index;
  final String name;
  final double start;
  final double end;
  final String primaryFunction;
  final String secondaryFunction;
  final RangeData range;
  final List<String> modes;
  final List<Reading> readings;

  DateTime get startTime => meterTimeToDateTime(start);

  DateTime get endTime => meterTimeToDateTime(end);

  @override
  List<Object?> get props => [
    kind,
    index,
    name,
    start,
    end,
    primaryFunction,
    secondaryFunction,
    range,
    modes,
    readings,
  ];
}

/// A saved single measurement.
class MemoryMeasurement extends Equatable {
  const MemoryMeasurement({
    required this.index,
    required this.name,
    required this.primaryFunction,
    required this.secondaryFunction,
    required this.range,
    required this.modes,
    required this.readings,
  });

  final int index;
  final String name;
  final String primaryFunction;
  final String secondaryFunction;
  final RangeData range;
  final List<String> modes;
  final List<Reading> readings;

  /// When the measurement was taken (time of its primary reading).
  DateTime? get time {
    for (final r in readings) {
      if (r.id == 'PRIMARY') return r.time;
    }
    return readings.isEmpty ? null : readings.first.time;
  }

  @override
  List<Object?> get props => [
    index,
    name,
    primaryFunction,
    secondaryFunction,
    range,
    modes,
    readings,
  ];
}
