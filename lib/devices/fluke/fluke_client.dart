library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../adapters/serial_channel.dart';
import '../../meter/meter_link.dart';
import '../../meter/meter_memory.dart';
import '../../meter/model/meter_display.dart';
import '../../meter/model/meter_exceptions.dart';
import '../../meter/model/meter_identity.dart';
import '../../meter/model/meter_properties.dart';
import 'fluke_memory_reader.dart';
import 'qdda.dart';

/// The command was refused with [ack].
MeterCommandRejected ackException(String command, String ack) =>
    MeterCommandRejected(command, switch (ack) {
      '1' => MeterCommandError.syntax,
      '2' => MeterCommandError.execution,
      '5' => MeterCommandError.noData,
      _ => MeterCommandError.other,
    }, ack);

const int _cr = 0x0D;
const int _lf = 0x0A;

class FlukeClient implements MeterLink {
  FlukeClient(this._channel);

  final SerialChannel _channel;
  final List<int> _buffer = [];

  /// Commands run one at a time, so live polling and memory downloads can
  /// share the connection.
  Future<void> _queue = Future.value();

  static const defaultTimeout = Duration(seconds: 2);
  static const _binaryTimeout = Duration(seconds: 4);

  static const _busyAck = '8';
  static const _busyRetries = 10;

  @override
  late final MeterMemory memory = FlukeMemoryReader(this);

  @override
  Stream<void> get onRemoved => _channel.onRemoved;

  @override
  Future<MeterIdentity> identify({Duration timeout = defaultTimeout}) async =>
      parseIdentity(await command('ID', timeout: timeout));

  @override
  Future<MeterDisplay> queryDisplay() async =>
      parseDisplay(await command('QDDA'));

  /// Reads each property on its own: a meter that does not know one
  /// answers it with an error, the others are still read. Stops at the
  /// first timeout, the meter would not answer the rest either.
  @override
  Future<MeterProperties> readProperties() async {
    final values = <String, String?>{};
    for (final name in MeterProperties.names) {
      try {
        values[name] = splitFields(await command('qmpq $name')).first;
      } on MeterCommandRejected {
        values[name] = null;
      } on MeterTimeoutException {
        break;
      }
    }
    return MeterProperties.fromMap(values);
  }

  @override
  Future<void> writeProperty(String name, String value) {
    if (!MeterProperties.names.contains(name) ||
        value
            .split('')
            .any((c) => !MeterProperties.allowedCharacters.hasMatch(c))) {
      throw ArgumentError('Invalid property $name: "$value"');
    }
    return command("mpq $name,'$value'", expectResponse: false);
  }

  Future<String> command(
    String cmd, {
    Duration timeout = defaultTimeout,
    bool expectResponse = true,
  }) => _exclusive(() async {
    final deadline = await _send(cmd, timeout);
    if (!expectResponse) return '';
    return _readLine(cmd, deadline);
  });

  /// Sends [cmd] and splits its text response at commas (respecting quoted
  /// strings), e.g. for `qsls` and `qemap`.
  Future<List<String>> textCommand(String cmd) async =>
      splitFields(await command(cmd));

  /// Sends [cmd] and returns the payload of its binary response
  /// (`0\r#0<payload>\r`).
  ///
  /// The payload may contain `\r`, so its end is found from its layout:
  /// either a fixed [length], or [minLength] computed from the payload's
  /// header (`null` until enough bytes have arrived) followed by text that
  /// ends with `\r`.
  Future<Uint8List> binaryCommand(
    String cmd, {
    int? length,
    int? Function(Uint8List payload)? minLength,
  }) => _exclusive(() async {
    final deadline = await _send(cmd, _binaryTimeout);
    await _fill(cmd, deadline, () => _buffer.length >= 2);
    if (_buffer[0] != 0x23 || _buffer[1] != 0x30) {
      final line = await _readLine(cmd, deadline);
      throw MeterParseException('$cmd: expected binary data, got "$line"');
    }
    _buffer.removeRange(0, 2);

    bool complete() {
      if (_buffer.isEmpty || _buffer.last != _cr) return false;
      if (length != null) return _buffer.length >= length + 1;
      final payload = Uint8List.fromList(_buffer);
      final min = minLength?.call(payload);
      return min != null && _buffer.length > min;
    }

    await _fill(cmd, deadline, complete);
    final end = length ?? _buffer.length - 1;
    final payload = Uint8List.fromList(_buffer.sublist(0, end));
    _buffer.clear();
    return payload;
  });

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<DateTime> _send(String cmd, Duration timeout) async {
    for (var attempt = 0; ; attempt++) {
      _buffer.clear();
      await _channel.write(ascii.encode('$cmd\r'));
      final deadline = DateTime.now().add(timeout);
      final ack = await _readLine(cmd, deadline);
      if (ack == '0') return deadline;
      if (ack != _busyAck || attempt >= _busyRetries) {
        throw ackException(cmd, ack);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Reads from the channel until [done] or the deadline.
  Future<void> _fill(
    String cmd,
    DateTime deadline,
    bool Function() done,
  ) async {
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        _buffer.clear();
        throw MeterTimeoutException(cmd);
      }
      final chunk = await _channel.read();
      if (chunk.isEmpty) {
        // Yield so a fake/WebUSB channel that returns immediately does not
        // starve the event loop.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      } else {
        _buffer.addAll(chunk);
      }
    }
  }

  Future<String> _readLine(String cmd, DateTime deadline) async {
    var line = '';
    await _fill(cmd, deadline, () {
      // Skip line feeds and empty lines some adapters/firmwares emit.
      while (_buffer.isNotEmpty &&
          (_buffer.first == _lf || _buffer.first == _cr)) {
        _buffer.removeAt(0);
      }
      final end = _buffer.indexOf(_cr);
      if (end < 0) return false;
      line = latin1.decode(_buffer.sublist(0, end)).trim();
      _buffer.removeRange(0, end + 1);
      return true;
    });
    return line;
  }

  @override
  Future<void> close() => _channel.close();
}

/// Splits a text response at commas. Fields may be quoted with `'` (a
/// doubled `''` is a literal quote) or `"`.
List<String> splitFields(String text) {
  final fields = <String>[];
  final current = StringBuffer();
  String? quote;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quote != null) {
      if (c == quote) {
        if (quote == "'" && i + 1 < text.length && text[i + 1] == "'") {
          current.write("'");
          i++;
        } else {
          quote = null;
        }
      } else {
        current.write(c);
      }
    } else if ((c == "'" || c == '"') && current.isEmpty) {
      quote = c;
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
