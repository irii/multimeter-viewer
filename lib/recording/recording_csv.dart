/// CSV format of a recording: `# key: value` metadata lines, then a header
/// row and one row per sample. Keys and column names are English whatever
/// the app language. The time base is the meter clock (`time`, `seconds`);
/// the system time each reading was received is stored next to it. Times are
/// UTC ISO-8601 plus local columns, values in base units.
library;

import '../about/app_info.dart';
import '../fluke/qdda.dart';
import 'recording.dart';

enum RecordingFormatError {
  /// A required column ([RecordingFormatException.detail]) is missing.
  missingColumn,

  /// No header row with readings was found.
  noTable,

  /// A row ([RecordingFormatException.line]) has no valid time.
  invalidTime,
}

class RecordingFormatException implements Exception {
  const RecordingFormatException(this.error, {this.detail, this.line});

  final RecordingFormatError error;
  final String? detail;
  final int? line;

  @override
  String toString() =>
      'RecordingFormatException: ${error.name}'
      '${detail == null ? '' : ' ($detail)'}'
      '${line == null ? '' : ' line $line'}';
}

abstract final class _Meta {
  /// App and version that wrote the file.
  static const app = 'App';
  static const appVersion = 'App version';

  /// Who made the recording ([RecordingOrigin.name]).
  static const origin = 'Source';
  static const name = 'Name';
  static const identifier = 'Identifier';
  static const comment = 'Comment';

  /// meter time of the first sample.
  static const start = 'Start';

  /// System time the recording was started.
  static const systemStart = 'System start';

  /// meter time of the end of the recording.
  static const end = 'End';
  static const plannedSeconds = 'Planned duration (s)';
  static const durationSeconds = 'Duration (s)';
  static const sampleCount = 'Samples';
  static const intervalSeconds = 'Interval (s)';
  static const eventThresholdPercent = 'Event threshold (%)';
  static const stopReason = 'Stopped';
  static const model = 'Model';
  static const firmware = 'Firmware';
  static const serial = 'Serial number';
}

abstract final class _Col {
  static const time = 'time';

  /// Local meter time, for reading the file by eye / in a spreadsheet.
  static const clock = 'local_time';

  /// System time the reading was received (UTC) and its local form.
  static const systemTime = 'system_time';
  static const systemClock = 'system_local_time';
  static const seconds = 'seconds';
  static const function = 'function';
  static const value = 'value';
  static const unit = 'unit';
  static const multiplier = 'multiplier';
  static const decimals = 'decimals';
  static const state = 'state';
  static const attribute = 'attribute';
  static const secondaryValue = 'secondary_value';
  static const secondaryUnit = 'secondary_unit';
  static const modes = 'modes';

  /// Interval values of recordings made by the meter (empty otherwise).
  static const minimum = 'minimum';
  static const maximum = 'maximum';
  static const average = 'average';
  static const intervalSeconds = 'interval_s';

  static const secondaryFunction = 'secondary_function';

  /// Measuring range: `AUTO`/`MANUAL`, range number, unit and multiplier.
  static const autoRange = 'auto_range';
  static const range = 'range';
  static const rangeUnit = 'range_unit';
  static const rangeMultiplier = 'range_multiplier';

  /// Sample details of recordings made by the meter (empty otherwise).
  static const recordType = 'record_type';
  static const stable = 'stable';
  static const transientState = 'transient_state';

  static const all = [
    time,
    clock,
    systemTime,
    systemClock,
    seconds,
    function,
    value,
    unit,
    multiplier,
    decimals,
    state,
    attribute,
    secondaryValue,
    secondaryUnit,
    modes,
    minimum,
    maximum,
    average,
    intervalSeconds,
    secondaryFunction,
    autoRange,
    range,
    rangeUnit,
    rangeMultiplier,
    recordType,
    stable,
    transientState,
  ];
}

String recordingToCsv(Recording recording) {
  final out = StringBuffer();
  void meta(String key, String value) =>
      out.writeln('# $key: ${_escapeMeta(value)}');

  final info = recording.info;
  meta(_Meta.app, AppInfo.name);
  meta(_Meta.appVersion, AppInfo.version);
  meta(_Meta.origin, recording.origin.name);
  meta(_Meta.name, info.name);
  meta(_Meta.identifier, info.identifier);
  meta(_Meta.comment, info.comment);
  meta(_Meta.start, recording.startedAt.toUtc().toIso8601String());
  if (recording.systemStartedAt != null) {
    meta(
      _Meta.systemStart,
      recording.systemStartedAt!.toUtc().toIso8601String(),
    );
  }
  meta(_Meta.end, recording.endedAt.toUtc().toIso8601String());
  meta(_Meta.plannedSeconds, '${info.duration.inSeconds}');
  meta(
    _Meta.durationSeconds,
    (recording.duration.inMilliseconds / 1000).toStringAsFixed(3),
  );
  meta(_Meta.sampleCount, '${recording.samples.length}');
  if (recording.sampleInterval case final interval?) {
    meta(
      _Meta.intervalSeconds,
      (interval.inMicroseconds / 1e6).toStringAsFixed(3),
    );
  }
  if (recording.eventThreshold case final threshold?) {
    meta(_Meta.eventThresholdPercent, _number(threshold * 100));
  }
  if (recording.stopReason != null) {
    meta(_Meta.stopReason, recording.stopReason!.name);
  }
  final identity = recording.identity;
  if (identity != null) {
    meta(_Meta.model, identity.model);
    meta(_Meta.firmware, identity.firmware);
    meta(_Meta.serial, identity.serial);
  }

  out.writeln(_row(_Col.all));
  for (final s in recording.samples) {
    final p = s.primary;
    final sec = s.secondary;
    final range = s.range;
    out.writeln(
      _row([
        p.time.toUtc().toIso8601String(),
        _localClock(p.time),
        s.systemTime?.toUtc().toIso8601String() ?? '',
        s.systemTime == null ? '' : _localClock(s.systemTime!),
        (s.elapsed.inMilliseconds / 1000).toStringAsFixed(3),
        s.primaryFunction,
        p.hasValue ? '${p.value}' : '',
        p.baseUnit,
        '${p.multiplier}',
        '${p.decimalPlaces}',
        p.state,
        p.attribute,
        sec != null && sec.hasValue ? '${sec.value}' : '',
        sec?.baseUnit ?? '',
        s.modes.join(' '),
        _value(s.minimum),
        _value(s.maximum),
        _value(s.average),
        s.interval == null
            ? ''
            : (s.interval!.inMilliseconds / 1000).toStringAsFixed(1),
        s.secondaryFunction ?? '',
        range == null ? '' : (range.autoRange ? 'AUTO' : 'MANUAL'),
        range == null ? '' : '${range.rangeNumber}',
        range?.baseUnit ?? '',
        range == null ? '' : '${range.multiplier}',
        s.recordType ?? '',
        switch (s.stable) {
          true => '1',
          false => '0',
          null => '',
        },
        s.transientState ?? '',
      ]),
    );
  }
  return out.toString();
}

Recording recordingFromCsv(String csv) {
  final meta = <String, String>{};
  List<String>? header;
  final samples = <RecordingSample>[];

  final lines = csv.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    if (line.startsWith('#')) {
      final sep = line.indexOf(':');
      if (sep > 0) {
        meta[line.substring(1, sep).trim()] = _unescapeMeta(
          line.substring(sep + 1).trimLeft(),
        );
      }
      continue;
    }
    final fields = _parseRow(line);
    if (header == null) {
      header = [for (final f in fields) f.trim()];
      for (final required in const [_Col.seconds, _Col.value, _Col.unit]) {
        if (!header.contains(required)) {
          throw RecordingFormatException(
            RecordingFormatError.missingColumn,
            detail: required,
          );
        }
      }
      continue;
    }
    String field(String name) {
      final index = header!.indexOf(name);
      return index >= 0 && index < fields.length ? fields[index] : '';
    }

    samples.add(_sampleFromRow(field, i + 1));
  }

  if (header == null) {
    throw const RecordingFormatException(RecordingFormatError.noTable);
  }

  final startedAt =
      DateTime.tryParse(meta[_Meta.start] ?? '')?.toLocal() ??
      (samples.isEmpty ? DateTime.now() : samples.first.primary.time);
  final model = meta[_Meta.model];
  final durationSeconds = double.tryParse(meta[_Meta.durationSeconds] ?? '');
  final intervalSeconds = double.tryParse(meta[_Meta.intervalSeconds] ?? '');
  final thresholdPercent = double.tryParse(
    meta[_Meta.eventThresholdPercent] ?? '',
  );

  return Recording(
    info: RecordingInfo(
      name: meta[_Meta.name] ?? '',
      identifier: meta[_Meta.identifier] ?? '',
      comment: meta[_Meta.comment] ?? '',
      duration: Duration(
        seconds: int.tryParse(meta[_Meta.plannedSeconds] ?? '') ?? 0,
      ),
    ),
    startedAt: startedAt,
    systemStartedAt: DateTime.tryParse(meta[_Meta.systemStart] ?? '')
        ?.toLocal(),
    duration: durationSeconds != null
        ? Duration(milliseconds: (durationSeconds * 1000).round())
        : (samples.isEmpty ? Duration.zero : samples.last.elapsed),
    samples: samples,
    identity: model == null
        ? null
        : MeterIdentity(
            model: model,
            firmware: meta[_Meta.firmware] ?? '',
            serial: meta[_Meta.serial] ?? '',
          ),
    stopReason: _parseStopReason(meta[_Meta.stopReason]),
    origin:
        RecordingOrigin.values.asNameMap()[meta[_Meta.origin]] ??
        RecordingOrigin.app,
    sampleInterval: intervalSeconds == null
        ? null
        : Duration(microseconds: (intervalSeconds * 1e6).round()),
    eventThreshold: thresholdPercent == null ? null : thresholdPercent / 100,
  );
}

RecordingSample _sampleFromRow(String Function(String) field, int lineNo) {
  final seconds = double.tryParse(field(_Col.seconds));
  if (seconds == null) {
    throw RecordingFormatException(
      RecordingFormatError.invalidTime,
      line: lineNo,
    );
  }
  final time = DateTime.tryParse(field(_Col.time));
  final timestamp = time == null ? seconds : dateTimeToMeterTime(time);
  final value = double.tryParse(field(_Col.value));
  final state = field(_Col.state);

  Reading reading(String id, double? v, String unit, String readingState) =>
      Reading(
        id: id,
        value: v ?? 0,
        baseUnit: unit,
        multiplier: int.tryParse(field(_Col.multiplier)) ?? 0,
        decimalPlaces: int.tryParse(field(_Col.decimals)) ?? 3,
        displayDigits: 5,
        state: readingState,
        attribute: id == 'PRIMARY' && field(_Col.attribute).isNotEmpty
            ? field(_Col.attribute)
            : 'NONE',
        timestamp: timestamp,
      );

  /// Interval reading of [column], `null` if the column is empty or absent.
  Reading? interval(String id, String column) {
    final v = double.tryParse(field(column));
    return v == null ? null : reading(id, v, field(_Col.unit), 'NORMAL');
  }

  String? optional(String column) {
    final value = field(column);
    return value.isEmpty ? null : value;
  }

  final rangeNumber = int.tryParse(field(_Col.range));
  final secondaryUnit = field(_Col.secondaryUnit);
  final secondaryValue = double.tryParse(field(_Col.secondaryValue));
  final modes = field(_Col.modes);

  return RecordingSample(
    elapsed: Duration(milliseconds: (seconds * 1000).round()),
    systemTime: DateTime.tryParse(field(_Col.systemTime))?.toLocal(),
    primaryFunction: field(_Col.function),
    primary: reading(
      'PRIMARY',
      value,
      field(_Col.unit),
      state.isNotEmpty ? state : (value == null ? 'INVALID' : 'NORMAL'),
    ),
    secondary: secondaryUnit.isEmpty
        ? null
        : reading(
            'SECONDARY',
            secondaryValue,
            secondaryUnit,
            secondaryValue == null ? 'INVALID' : 'NORMAL',
          ),
    modes: modes.isEmpty ? const [] : modes.split(' '),
    minimum: interval('MINIMUM', _Col.minimum),
    maximum: interval('MAXIMUM', _Col.maximum),
    average: interval('AVERAGE', _Col.average),
    interval: switch (double.tryParse(field(_Col.intervalSeconds))) {
      final s? => Duration(milliseconds: (s * 1000).round()),
      null => null,
    },
    secondaryFunction: optional(_Col.secondaryFunction),
    range: rangeNumber == null
        ? null
        : RangeData(
            autoRange: field(_Col.autoRange) == 'AUTO',
            baseUnit: field(_Col.rangeUnit),
            rangeNumber: rangeNumber,
            multiplier: int.tryParse(field(_Col.rangeMultiplier)) ?? 0,
          ),
    recordType: optional(_Col.recordType),
    stable: switch (field(_Col.stable)) {
      '1' => true,
      '0' => false,
      _ => null,
    },
    transientState: optional(_Col.transientState),
  );
}

/// [value] rounded to 4 decimals, without a trailing `.0`, e.g. `4`, `2.5`.
String _number(double value) {
  final rounded = double.parse(value.toStringAsFixed(4));
  return rounded == rounded.roundToDouble() ? '${rounded.round()}' : '$rounded';
}

String _value(Reading? reading) =>
    reading != null && reading.hasValue ? '${reading.value}' : '';

String _escapeMeta(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('\r', '').replaceAll('\n', r'\n');

String _unescapeMeta(String value) =>
    value.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1] == 'n' ? '\n' : m[1]!);

String _row(List<String> fields) => fields.map(_escapeField).join(',');

String _escapeField(String field) {
  if (field.contains(RegExp('[",\r\n]'))) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

/// Splits one CSV line, honoring double-quoted fields.
List<String> _parseRow(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        current.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      fields.add(current.toString());
      current.clear();
    } else {
      current.write(c);
    }
  }
  fields.add(current.toString());
  return fields;
}

/// File name derived from the recording name, e.g. `Motor_A_2026-10-28_1405.csv`.
String suggestedFileName(RecordingInfo info, DateTime startedAt) {
  String two(int v) => v.toString().padLeft(2, '0');
  final base = info.name.trim().isEmpty
      ? 'Recording'
      : info.name.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
  return '${base}_${startedAt.year}-${two(startedAt.month)}-'
      '${two(startedAt.day)}_${two(startedAt.hour)}${two(startedAt.minute)}.csv';
}

/// `2026-10-28 14:05:01.200` in local time.
String _localClock(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} '
      '${two(l.hour)}:${two(l.minute)}:${two(l.second)}.'
      '${l.millisecond.toString().padLeft(3, '0')}';
}

/// Stop reasons are stored by name.
RecordingStopReason? _parseStopReason(String? value) =>
    RecordingStopReason.values.asNameMap()[value];
