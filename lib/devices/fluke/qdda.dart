import '../../meter/model/meter_display.dart';
import '../../meter/model/meter_exceptions.dart';
import '../../meter/model/meter_identity.dart';

/// Parses the answer to `ID`.
MeterIdentity parseIdentity(String response) {
  final parts = response.split(',').map((p) => p.trim()).toList();
  if (parts.length < 3 || !parts[0].toUpperCase().startsWith('FLUKE')) {
    throw MeterParseException('Unexpected ID response: "$response"');
  }
  return MeterIdentity(model: parts[0], firmware: parts[1], serial: parts[2]);
}

/// Parses the answer to `QDDA`.
MeterDisplay parseDisplay(String response) => _DisplayParser(response).parse();

class _DisplayParser {
  _DisplayParser(String response)
    : _tokens = response.split(',').map((t) => t.trim()).toList(),
      _response = response;

  final String _response;
  final List<String> _tokens;
  int _pos = 0;

  MeterDisplay parse() {
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
    return MeterDisplay(
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
      throw MeterParseException('QDDA response too short: "$_response"');
    }
    return _tokens[_pos++];
  }

  int _int() {
    final token = _next();
    return int.tryParse(token) ??
        (throw MeterParseException('Expected integer, got "$token"'));
  }

  double _double() {
    final token = _next();
    return double.tryParse(token) ??
        (throw MeterParseException('Expected number, got "$token"'));
  }
}
