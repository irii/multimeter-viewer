library;

import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'dart:typed_data';

import 'fluke_memory_reader.dart';
import 'qdda.dart';

export 'fluke_memory_reader.dart' show MeterMemory;

/// Byte transport to the meter (the FTDI cable in production, fakes in
/// tests).
abstract interface class SerialChannel {
  Future<void> write(List<int> data);

  /// Returns whatever bytes have arrived; may be empty.
  Future<List<int>> read();

  /// Fires when the underlying device is unplugged.
  Stream<void> get onRemoved;

  Future<void> close();
}

/// What the UI layer needs from a connected meter.
abstract interface class MeterLink {
  Future<MeterIdentity> identify();

  Future<QddaResponse> queryDisplay();

  Stream<void> get onRemoved;

  /// Access to recordings and measurements saved in the meter.
  MeterMemory get memory;

  Future<void> close();
}

/// Error reported for a meter [command]. The UI turns these into localized
/// text; [toString] is a technical English description for logs.
sealed class FlukeException extends Equatable implements Exception {
  const FlukeException(this.command);

  final String command;
}

final class FlukeAckException extends FlukeException {
  const FlukeAckException(super.command, this.ack);

  final String ack;

  @override
  List<Object?> get props => [command, ack];

  @override
  String toString() => '$command: CMD_ACK $ack';
}

/// The meter did not answer [command] in time.
final class FlukeTimeoutException extends FlukeException {
  const FlukeTimeoutException(super.command);

  @override
  List<Object?> get props => [command];

  @override
  String toString() => '$command: no response from the meter';
}

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
      MeterIdentity.parse(await command('ID', timeout: timeout));

  @override
  Future<QddaResponse> queryDisplay() async =>
      QddaResponse.parse(await command('QDDA'));

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
      throw FlukeParseException('$cmd: expected binary data, got "$line"');
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
        throw FlukeAckException(cmd, ack);
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
        throw FlukeTimeoutException(cmd);
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
