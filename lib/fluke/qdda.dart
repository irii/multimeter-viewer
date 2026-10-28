library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'units.dart';

/// The meter sent data that does not match the protocol.
class FlukeParseException extends Equatable implements Exception {
  const FlukeParseException(this.message);

  /// Technical English description.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'FlukeParseException: $message';
}

enum MeterModel {
  fluke287('Fluke 287'),
  fluke289('Fluke 289'),

  /// Answers like a Fluke but is not a 287/289; may work, untested.
  unknown('Fluke');

  const MeterModel(this.label);

  final String label;

  static const supported = [fluke287, fluke289];

  bool get isSupported => supported.contains(this);

  /// Display names of all supported models, e.g. `Fluke 287/289`.
  static String get supportedLabel =>
      'Fluke ${supported.map((m) => m.label.split(' ').last).join('/')}';
}

class MeterIdentity extends Equatable {
  const MeterIdentity({
    required this.model,
    required this.firmware,
    required this.serial,
  });

  factory MeterIdentity.parse(String response) {
    final parts = response.split(',').map((p) => p.trim()).toList();
    if (parts.length < 3 || !parts[0].toUpperCase().startsWith('FLUKE')) {
      throw FlukeParseException('Unexpected ID response: "$response"');
    }
    return MeterIdentity(model: parts[0], firmware: parts[1], serial: parts[2]);
  }

  /// Model as reported by the meter, e.g. `FLUKE 287`.
  final String model;
  final String firmware;
  final String serial;

  /// Model family derived from [model]. The 287 and 289 share the protocol;
  /// the 287 just lacks some functions (LoZ, LoΩ).
  MeterModel get meterModel {
    final number = RegExp(r'\b(\d{3})\b').firstMatch(model)?.group(1);
    return switch (number) {
      '287' => MeterModel.fluke287,
      '289' => MeterModel.fluke289,
      _ => MeterModel.unknown,
    };
  }

  @override
  List<Object?> get props => [model, firmware, serial];
}

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

class QddaResponse extends Equatable {
  const QddaResponse({
    required this.primaryFunction,
    required this.secondaryFunction,
    required this.range,
    required this.lightningBolt,
    required this.minMaxStartTime,
    required this.modes,
    required this.readings,
  });

  factory QddaResponse.parse(String response) => _QddaParser(response).parse();

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

class _QddaParser {
  _QddaParser(String response)
    : _tokens = response.split(',').map((t) => t.trim()).toList(),
      _response = response;

  final String _response;
  final List<String> _tokens;
  int _pos = 0;

  QddaResponse parse() {
    final primaryFunction = _next();
    final secondaryFunction = _next();
    final range = RangeData(
      autoRange: _next() == 'AUTO',
      baseUnit: _next(),
      rangeNumber: _int(),
      multiplier: _int(),
    );
    final lightningBolt = _next() == 'ON';
    final minMaxStartTime = _double();
    final modeCount = _int();
    final modes = [for (var i = 0; i < modeCount; i++) _next()];
    final readingCount = _int();
    final readings = [
      for (var i = 0; i < readingCount; i++)
        Reading(
          id: _next(),
          value: _double(),
          baseUnit: _next(),
          multiplier: _int(),
          decimalPlaces: _int(),
          displayDigits: _int(),
          state: _next(),
          attribute: _next(),
          timestamp: _double(),
        ),
    ];
    return QddaResponse(
      primaryFunction: primaryFunction,
      secondaryFunction: secondaryFunction,
      range: range,
      lightningBolt: lightningBolt,
      minMaxStartTime: minMaxStartTime,
      modes: modes,
      readings: readings,
    );
  }

  String _next() {
    if (_pos >= _tokens.length) {
      throw FlukeParseException('QDDA response too short: "$_response"');
    }
    return _tokens[_pos++];
  }

  int _int() {
    final token = _next();
    return int.tryParse(token) ??
        (throw FlukeParseException('Expected integer, got "$token"'));
  }

  double _double() {
    final token = _next();
    return double.tryParse(token) ??
        (throw FlukeParseException('Expected number, got "$token"'));
  }
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
