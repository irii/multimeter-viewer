/// Reading the memory of a Fluke 287/289: saved recordings (TrendCapture),
/// min/max and peak sessions and saved measurements.
///
/// These commands are undocumented. The binary layouts follow the
/// reverse-engineered descriptions of `dmm_util` by Fredrik Valeur
/// (https://github.com/fvaleur/dmm_util, MIT) and its Python port
/// `fluke-28x-dmm-util` (https://github.com/N0ury/dmm_util, MIT).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'qdda.dart';

/// Number of entries per memory category (`qsls`).
class MemoryCounts extends Equatable {
  const MemoryCounts({
    required this.recordings,
    required this.minMax,
    required this.peak,
    required this.measurements,
  });

  factory MemoryCounts.parse(List<String> fields) {
    if (fields.length < 4) {
      throw FlukeParseException('Unexpected qsls response: $fields');
    }
    int at(int i) =>
        int.tryParse(fields[i].trim()) ??
        (throw FlukeParseException('Unexpected qsls response: $fields'));
    return MemoryCounts(
      recordings: at(0),
      minMax: at(1),
      peak: at(2),
      measurements: at(3),
    );
  }

  final int recordings;
  final int minMax;
  final int peak;
  final int measurements;

  @override
  List<Object?> get props => [recordings, minMax, peak, measurements];
}

/// The meter's value maps (`qemap <name>`): numeric code → identifier such as
/// `V_AC` or `NORMAL`, as used in the binary responses.
class MeterMaps {
  MeterMaps(this._maps);

  /// Maps the binary responses refer to.
  static const names = [
    'primfunction',
    'secfunction',
    'autorange',
    'unit',
    'bolt',
    'mode',
    'readingid',
    'state',
    'attribute',
    'recordtype',
    'isstableflag',
    'transientstate',
  ];

  final Map<String, Map<int, String>> _maps;

  /// Parses a `qemap` response: `count,code,name,code,name,...`.
  static Map<int, String> parseMap(List<String> fields) {
    final count = int.tryParse(fields.isEmpty ? '' : fields.first.trim());
    if (count == null || fields.length != 1 + count * 2) {
      throw FlukeParseException('Unexpected qemap response: $fields');
    }
    return {
      for (var i = 0; i < count; i++)
        int.parse(fields[1 + i * 2].trim()): fields[2 + i * 2].trim(),
    };
  }

  /// Identifier for [code] in [map]; unknown codes become `#<code>` rather
  /// than failing, so newer firmware does not break the download.
  String value(String map, int code) => _maps[map]?[code] ?? '#$code';

  /// Identifiers of all bits set in [bits] (bit-flag maps such as `mode`).
  List<String> flags(String map, int bits) {
    final entries = _maps[map] ?? const {};
    return [
      for (final code in entries.keys.toList()..sort())
        if (code != 0 && bits & code == code) entries[code]!,
    ];
  }
}

/// Little-endian reader for the meter's binary responses.
class _Bytes {
  _Bytes(this.bytes);

  final Uint8List bytes;
  late final _data = ByteData.sublistView(bytes);

  int get length => bytes.length;

  int u16(int offset) => _data.getUint16(offset, Endian.little);

  int s16(int offset) => _data.getInt16(offset, Endian.little);

  /// Doubles are stored as two little-endian 32-bit words, high word first.
  double f64(int offset) {
    final swapped = ByteData(8)
      ..setUint32(0, _data.getUint32(offset, Endian.little))
      ..setUint32(4, _data.getUint32(offset + 4, Endian.little));
    return swapped.getFloat64(0);
  }

  /// Text from [offset] to the end, without padding.
  String text(int offset) => offset >= length
      ? ''
      : latin1.decode(bytes.sublist(offset)).replaceAll('\u0000', '').trim();

  void require(int size, String what) {
    if (length < size) {
      throw FlukeParseException('$what: expected $size bytes, got $length');
    }
  }
}

const _readingSize = 30;

Reading _reading(_Bytes b, int offset, MeterMaps maps) => Reading(
  id: maps.value('readingid', b.u16(offset)),
  value: b.f64(offset + 2),
  baseUnit: maps.value('unit', b.u16(offset + 10)),
  multiplier: b.s16(offset + 12),
  decimalPlaces: b.s16(offset + 14),
  displayDigits: b.s16(offset + 16),
  state: maps.value('state', b.u16(offset + 18)),
  attribute: maps.value('attribute', b.u16(offset + 20)),
  timestamp: b.f64(offset + 22),
);

List<Reading> _readings(_Bytes b, int offset, int count, MeterMaps maps) => [
  for (var i = 0; i < count; i++) _reading(b, offset + i * _readingSize, maps),
];

RangeData _range(_Bytes b, int offset, MeterMaps maps) => RangeData(
  autoRange: maps.value('autorange', b.u16(offset)) == 'AUTO',
  baseUnit: maps.value('unit', b.u16(offset + 2)),
  rangeNumber: b.f64(offset + 4).round(),
  multiplier: b.s16(offset + 12),
);

/// A recording stored in the meter (`qrsi <index>`).
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

  /// Payload length up to (and including) the reading count at offset 76.
  static const headerSize = 78;

  /// Minimum payload length once the header is known.
  static int? minLength(Uint8List payload) => payload.length < headerSize
      ? null
      : headerSize + _Bytes(payload).u16(76) * _readingSize;

  factory MemoryRecording.parse(int index, Uint8List payload, MeterMaps maps) {
    final b = _Bytes(payload)..require(headerSize, 'qrsi');
    final count = b.u16(76);
    b.require(headerSize + count * _readingSize, 'qrsi');
    return MemoryRecording(
      index: index,
      start: b.f64(4),
      end: b.f64(12),
      sampleInterval: b.f64(20),
      eventThreshold: b.f64(28),
      readingIndex: b.u16(36),
      sampleCount: b.u16(40),
      primaryFunction: maps.value('primfunction', b.u16(44)),
      secondaryFunction: maps.value('secfunction', b.u16(46)),
      range: _range(b, 48, maps),
      modes: maps.flags('mode', b.u16(72)),
      readings: _readings(b, headerSize, count, maps),
      name: b.text(headerSize + count * _readingSize),
    );
  }

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

  /// Key for [MemoryRecordingSample] queries (`qsrr <readingIndex>,<n>`).
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

/// One interval of a recording (`qsrr <readingIndex>,<sample>`).
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

  /// Fixed payload length.
  static const size = 146;

  factory MemoryRecordingSample.parse(Uint8List payload, MeterMaps maps) {
    final b = _Bytes(payload)..require(size, 'qsrr');
    final intervalReadings = _readings(b, 16, 3, maps);
    final latest = _readings(b, 110, 1, maps);
    // Interval length in 0.1 s steps.
    final ticks = b.u16(106);
    Reading? byId(String id) {
      for (final r in [...intervalReadings, ...latest]) {
        if (r.id == id) return r;
      }
      return null;
    }

    // The meter reports the AVERAGE as the sum over all 0.1 s ticks of the
    // interval, so divide by the tick count to get the mean.
    final sum = byId('AVERAGE');
    final average = sum == null || ticks == 0
        ? sum
        : Reading(
            id: sum.id,
            value: sum.value / ticks,
            baseUnit: sum.baseUnit,
            multiplier: sum.multiplier,
            decimalPlaces: sum.decimalPlaces,
            displayDigits: sum.displayDigits,
            state: sum.state,
            attribute: sum.attribute,
            timestamp: sum.timestamp,
          );

    return MemoryRecordingSample(
      start: b.f64(0),
      end: b.f64(8),
      primary: byId('PRIMARY') ?? latest.first,
      minimum: byId('MINIMUM'),
      maximum: byId('MAXIMUM'),
      average: average,
      duration: Duration(milliseconds: ticks * 100),
      recordType: maps.value('recordtype', b.u16(140)),
      stable: maps.value('isstableflag', b.u16(142)) == 'STABLE',
      transientState: maps.value('transientstate', b.u16(144)),
    );
  }

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

/// A saved min/max (`qmmsi`) or peak (`qpsi`) session.
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

  static const headerSize = 54;

  static int? minLength(Uint8List payload) => payload.length < headerSize
      ? null
      : headerSize + _Bytes(payload).u16(52) * _readingSize;

  factory MemorySession.parse(
    MemorySessionKind kind,
    int index,
    Uint8List payload,
    MeterMaps maps,
  ) {
    final b = _Bytes(payload)..require(headerSize, kind.name);
    final count = b.u16(52);
    b.require(headerSize + count * _readingSize, kind.name);
    return MemorySession(
      kind: kind,
      index: index,
      start: b.f64(4),
      end: b.f64(12),
      primaryFunction: maps.value('primfunction', b.u16(20)),
      secondaryFunction: maps.value('secfunction', b.u16(22)),
      range: _range(b, 24, maps),
      modes: maps.flags('mode', b.u16(48)),
      readings: _readings(b, headerSize, count, maps),
      name: b.text(headerSize + count * _readingSize),
    );
  }

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

/// A saved single measurement (`qsmr <index>`).
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

  static const headerSize = 38;

  static int? minLength(Uint8List payload) => payload.length < headerSize
      ? null
      : headerSize + _Bytes(payload).u16(36) * _readingSize;

  factory MemoryMeasurement.parse(
    int index,
    Uint8List payload,
    MeterMaps maps,
  ) {
    final b = _Bytes(payload)..require(headerSize, 'qsmr');
    final count = b.u16(36);
    b.require(headerSize + count * _readingSize, 'qsmr');
    return MemoryMeasurement(
      index: index,
      primaryFunction: maps.value('primfunction', b.u16(4)),
      secondaryFunction: maps.value('secfunction', b.u16(6)),
      range: _range(b, 8, maps),
      modes: maps.flags('mode', b.u16(32)),
      readings: _readings(b, headerSize, count, maps),
      name: b.text(headerSize + count * _readingSize),
    );
  }

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
