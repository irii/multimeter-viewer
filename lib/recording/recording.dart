import 'package:equatable/equatable.dart';

import '../fluke/qdda.dart';

/// What the user entered before starting a recording.
class RecordingInfo extends Equatable {
  const RecordingInfo({
    required this.name,
    required this.identifier,
    required this.comment,
    required this.duration,
  });

  final String name;

  /// Free reference such as a customer number.
  final String identifier;
  final String comment;
  final Duration duration;

  @override
  List<Object?> get props => [name, identifier, comment, duration];
}

/// Why a recording ended before its planned duration.
enum RecordingStopReason {
  /// Stopped by the user.
  stopped,

  /// The meter connection was lost.
  disconnected,
}

/// Who made a recording.
enum RecordingOrigin {
  /// Recorded live by this app.
  app,

  /// Recorded by the meter itself and read from its memory.
  meter,
}

/// One recorded meter display.
class RecordingSample extends Equatable {
  const RecordingSample({
    required this.elapsed,
    required this.primaryFunction,
    required this.primary,
    this.systemTime,
    this.secondary,
    this.secondaryFunction,
    this.range,
    this.modes = const [],
    this.minimum,
    this.maximum,
    this.average,
    this.interval,
    this.recordType,
    this.stable,
    this.transientState,
  });

  factory RecordingSample.fromDisplay(
    QddaResponse display,
    Duration elapsed, {
    required DateTime systemTime,
  }) => RecordingSample(
    elapsed: elapsed,
    systemTime: systemTime,
    primaryFunction: display.primaryFunction,
    primary: display.primary!,
    secondary: display.reading('SECONDARY'),
    secondaryFunction: display.secondaryFunction,
    range: display.range,
    modes: display.modes,
  );

  /// Time since the first sample of the recording, by the meter clock.
  final Duration elapsed;

  /// meter time of the reading.
  DateTime get meterTime => primary.time;

  /// System time the reading was received; `null` for recordings made by
  /// the meter itself.
  final DateTime? systemTime;
  final String primaryFunction;
  final Reading primary;
  final Reading? secondary;
  final String? secondaryFunction;

  /// Measuring range of the meter at this sample.
  final RangeData? range;
  final List<String> modes;

  /// Lowest, highest and average reading of the interval this sample covers
  /// (recordings made by the meter store one sample per interval).
  final Reading? minimum;
  final Reading? maximum;
  final Reading? average;

  /// Length of that interval.
  final Duration? interval;

  /// Recordings made by the meter: `INTERVAL` for a regular sample, `INPUT`
  /// for one triggered by a change of the input.
  final String? recordType;

  /// Recordings made by the meter: whether the input was stable.
  final bool? stable;
  final String? transientState;

  /// Reading to plot and summarize: the interval average if known, else the
  /// sampled reading.
  Reading get trend => average ?? primary;

  @override
  List<Object?> get props => [
    elapsed,
    systemTime,
    primaryFunction,
    primary,
    secondary,
    secondaryFunction,
    range,
    modes,
    minimum,
    maximum,
    average,
    interval,
    recordType,
    stable,
    transientState,
  ];
}

/// A complete recording: live from the [RecordingBloc] or loaded from CSV.
class Recording extends Equatable {
  const Recording({
    required this.info,
    required this.startedAt,
    required this.duration,
    required this.samples,
    this.systemStartedAt,
    this.identity,
    this.stopReason,
    this.origin = RecordingOrigin.app,
    this.sampleInterval,
    this.eventThreshold,
  });

  final RecordingInfo info;

  /// meter time of the first sample; the time base of the recording.
  final DateTime startedAt;

  /// System time the recording was started.
  final DateTime? systemStartedAt;

  /// Actual recorded length (may be shorter than [RecordingInfo.duration]).
  final Duration duration;
  final List<RecordingSample> samples;
  final MeterIdentity? identity;

  /// Why the recording ended early, if it did.
  final RecordingStopReason? stopReason;

  final RecordingOrigin origin;

  /// Time between samples: as set on the meter for its recordings, the
  /// measured mean for recordings of the app.
  final Duration? sampleInterval;

  /// Recordings made by the meter: relative change of the input that
  /// triggers an extra sample (e.g. 0.04 = 4 %).
  final double? eventThreshold;

  /// meter time of the end of the recording.
  DateTime get endedAt => startedAt.add(duration);

  /// Range shared by all samples, `null` if it changed or is unknown.
  RangeData? get range {
    final ranges = samples.map((s) => s.range).toSet();
    return ranges.length == 1 ? ranges.single : null;
  }

  /// Samples grouped by the primary base unit, in order of first appearance.
  Map<String, List<RecordingSample>> get samplesByUnit {
    final groups = <String, List<RecordingSample>>{};
    for (final s in samples) {
      (groups[s.primary.baseUnit] ??= []).add(s);
    }
    return groups;
  }

  @override
  List<Object?> get props => [
    info,
    startedAt,
    systemStartedAt,
    duration,
    samples,
    identity,
    stopReason,
    origin,
    sampleInterval,
    eventThreshold,
  ];
}
