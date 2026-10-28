import 'package:equatable/equatable.dart';

import '../fluke/qdda.dart';

/// One point of the primary-reading history. A `null` [value] marks a gap
/// (OL, invalid, blank, ...).
class SamplePoint extends Equatable {
  const SamplePoint(this.t, this.value, {this.systemT});

  /// Seconds since the first sample of the series (meter clock).
  final double t;

  /// Value in base units, or `null` for a gap.
  final double? value;

  /// Seconds since the first sample of the series by the system clock (time
  /// the reading was received), if known.
  final double? systemT;

  @override
  List<Object?> get props => [t, value, systemT];
}

/// Rolling history of the PRIMARY reading for the chart. The series restarts
/// whenever the base unit changes.
class SampleHistory extends Equatable {
  const SampleHistory({
    this.unit,
    this.start = 0,
    this.systemStart,
    this.points = const [],
  });

  static const int maxPoints = 600;

  /// Base unit of the series (e.g. `VDC`), `null` while empty.
  final String? unit;

  final double start;

  /// System time the first sample was received.
  final DateTime? systemStart;
  final List<SamplePoint> points;

  bool get hasValues => points.any((p) => p.value != null);

  DateTime get meterStart => meterTimeToDateTime(start);

  /// Returns the history with [reading] appended. [receivedAt] is the system
  /// time the reading arrived.
  SampleHistory append(Reading? reading, {DateTime? receivedAt}) {
    if (reading == null) return this;
    final value = reading.hasValue ? reading.value : null;

    if (reading.baseUnit != unit) {
      return SampleHistory(
        unit: reading.baseUnit,
        start: reading.timestamp,
        systemStart: receivedAt,
        points: [SamplePoint(0, value, systemT: receivedAt == null ? null : 0)],
      );
    }

    final t = reading.timestamp - start;
    // HOLD freezes the timestamp; don't pile up identical samples.
    if (points.isNotEmpty && t <= points.last.t) return this;

    if (value == null && points.isNotEmpty && points.last.value == null) {
      return this;
    }

    final systemStart = this.systemStart;
    final systemT = receivedAt == null || systemStart == null
        ? null
        : receivedAt.difference(systemStart).inMicroseconds / 1e6;
    final next = [...points, SamplePoint(t, value, systemT: systemT)];
    if (next.length > maxPoints) next.removeRange(0, next.length - maxPoints);
    return SampleHistory(
      unit: unit,
      start: start,
      systemStart: systemStart,
      points: next,
    );
  }

  @override
  List<Object?> get props => [unit, start, systemStart, points];
}
