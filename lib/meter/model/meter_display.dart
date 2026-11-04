import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'units.dart';

class RangeData extends Equatable {
  const RangeData({
    required this.autoRange,
    required this.baseUnit,
    required this.rangeNumber,
    required this.multiplier,
  });

  final bool autoRange;
  final String baseUnit;
  final int rangeNumber;
  final int multiplier;

  String get label =>
      '$rangeNumber ${prefixForMultiplier(multiplier)}${unitSymbol(baseUnit)}';

  @override
  List<Object?> get props => [autoRange, baseUnit, rangeNumber, multiplier];
}

class Reading extends Equatable {
  const Reading({
    required this.id,
    required this.value,
    required this.baseUnit,
    required this.multiplier,
    required this.decimalPlaces,
    required this.displayDigits,
    required this.state,
    required this.attribute,
    required this.timestamp,
  });

  final String id;

  final double value;
  final String baseUnit;
  final int multiplier;
  final int decimalPlaces;
  final int displayDigits;
  final String state;
  final String attribute;

  final double timestamp;

  /// Whether [value] is a real measurement (not OL, invalid, blank ...).
  bool get hasValue => state == 'NORMAL';

  /// Value as shown on the meter, without unit, e.g. `7.312`, `OL`.
  String get displayText {
    switch (state) {
      case 'OL':
        return 'OL';
      case 'OL_MINUS':
        return '-OL';
      case 'OPEN_TC':
        return 'Open TC';
      case 'DISCHARGE':
        return 'Discharge';
      case 'NORMAL':
        final scaled = value / math.pow(10, multiplier);
        return scaled.toStringAsFixed(decimalPlaces);
      default:
        return '----';
    }
  }

  /// [displayText] with a fixed sign column: `-` for negative values, a
  /// space otherwise (like the meter's LCD, which shows no `+`). In a
  /// monospace font the width then stays the same when the sign flips.
  String get signedDisplayText => withSignColumn(displayText);

  /// [signedDisplayText] right-aligned to the meter's full digit count for
  /// the current range (e.g. `  7.312` in the 50 mV range), with the sign
  /// column kept on the left. The text keeps its width while the value
  /// changes within a range, so a fitted display does not change size.
  String get fixedWidthDisplayText {
    final text = signedDisplayText;
    final sign = text[0];
    final body = text.substring(1);
    final intDigits = math.max(1, displayDigits - decimalPlaces);
    final width = intDigits + (decimalPlaces > 0 ? 1 + decimalPlaces : 0);
    return '$sign${body.padLeft(width)}';
  }

  /// Unit as shown on the meter, e.g. `mV AC`.
  String get unitText {
    final qualifier = unitQualifier(baseUnit);
    final symbol = '${prefixForMultiplier(multiplier)}${unitSymbol(baseUnit)}';
    return qualifier.isEmpty ? symbol : '$symbol $qualifier';
  }

  DateTime get time => meterTimeToDateTime(timestamp);

  @override
  List<Object?> get props => [
    id,
    value,
    baseUnit,
    multiplier,
    decimalPlaces,
    displayDigits,
    state,
    attribute,
    timestamp,
  ];
}

class MeterDisplay extends Equatable {
  const MeterDisplay({
    required this.primaryFunction,
    required this.secondaryFunction,
    required this.range,
    required this.lightningBolt,
    required this.minMaxStartTime,
    required this.modes,
    required this.readings,
  });

  final String primaryFunction;
  final String secondaryFunction;
  final RangeData range;
  final bool lightningBolt;

  final double minMaxStartTime;
  final List<String> modes;
  final List<Reading> readings;

  Reading? reading(String id) {
    for (final r in readings) {
      if (r.id == id) return r;
    }
    return null;
  }

  Reading? get primary => reading('PRIMARY');

  DateTime? get minMaxStart =>
      minMaxStartTime == 0 ? null : meterTimeToDateTime(minMaxStartTime);

  @override
  List<Object?> get props => [
    primaryFunction,
    secondaryFunction,
    range,
    lightningBolt,
    minMaxStartTime,
    modes,
    readings,
  ];
}

/// Prefixes [text] with a space unless it already starts with `-`, so a
/// sign change does not change its width (see [Reading.signedDisplayText]).
String withSignColumn(String text) => text.startsWith('-') ? text : ' $text';

/// Converts a meter timestamp to a local [DateTime].
///
/// The meter's clock knows no time zone; its timestamps are local
/// wall-clock times encoded as if they were UTC.
DateTime meterTimeToDateTime(double seconds) {
  final wall = DateTime.fromMicrosecondsSinceEpoch(
    (seconds * 1e6).round(),
    isUtc: true,
  );
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
}

/// Inverse of [meterTimeToDateTime].
double dateTimeToMeterTime(DateTime time) {
  final local = time.toLocal();
  return DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      ).microsecondsSinceEpoch /
      1e6;
}
