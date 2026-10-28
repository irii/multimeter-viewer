library;

String prefixForMultiplier(int multiplier) => switch (multiplier) {
  -12 => 'p',
  -9 => 'n',
  -6 => 'µ',
  -3 => 'm',
  0 => '',
  3 => 'k',
  6 => 'M',
  9 => 'G',
  _ => 'e$multiplier ',
};

/// Bare unit symbol, without the AC/DC qualifier.
String unitSymbol(String unit) => switch (unit) {
  'VDC' || 'VAC' || 'VAC_PLUS_DC' || 'V' => 'V',
  'ADC' || 'AAC' || 'AAC_PLUS_DC' || 'A' => 'A',
  'OHM' => 'Ω',
  'SIE' => 'S',
  'Hz' => 'Hz',
  'S' => 's',
  'F' => 'F',
  'CEL' => '°C',
  'FAR' => '°F',
  'PCT' => '%',
  'dBm' => 'dBm',
  'dBV' => 'dBV',
  'dB' => 'dB',
  'CREST_FACTOR' => 'CF',
  'NONE' => '',
  _ => unit,
};

/// AC/DC qualifier shown next to the unit symbol, or an empty string.
String unitQualifier(String unit) => switch (unit) {
  'VDC' || 'ADC' => 'DC',
  'VAC' || 'AAC' => 'AC',
  'VAC_PLUS_DC' || 'AAC_PLUS_DC' => 'AC+DC',
  _ => '',
};

/// Full unit label, e.g. `V DC`, `Ω`, `°C`.
String unitLabel(String unit) {
  final qualifier = unitQualifier(unit);
  final symbol = unitSymbol(unit);
  return qualifier.isEmpty ? symbol : '$symbol $qualifier';
}

/// Units whose values are not scaled with an SI prefix.
bool isUnscaledUnit(String unit) => const {
  'CEL',
  'FAR',
  'PCT',
  'dBm',
  'dBV',
  'dB',
  'CREST_FACTOR',
  'NONE',
}.contains(unit);

/// Chooses an engineering multiplier (multiple of 3) so that [maxAbs] shows
/// with 1–3 integer digits.
int multiplierForMagnitude(double maxAbs) {
  if (maxAbs == 0 || !maxAbs.isFinite) return 0;
  var exponent = 0;
  var v = maxAbs;
  while (v >= 1000 && exponent < 9) {
    v /= 1000;
    exponent += 3;
  }
  while (v < 1 && exponent > -9) {
    v *= 1000;
    exponent -= 3;
  }
  return exponent;
}

/// Formats a base-unit [value] with a fitting SI prefix, e.g. `12.345 mV AC`.
String formatQuantity(double value, String unit, {int precision = 5}) {
  final multiplier = isUnscaledUnit(unit)
      ? 0
      : multiplierForMagnitude(value.abs());
  final scaled = value / _pow10(multiplier);
  final qualifier = unitQualifier(unit);
  final symbol = '${prefixForMultiplier(multiplier)}${unitSymbol(unit)}';
  final number = scaled.toStringAsPrecision(precision);
  return qualifier.isEmpty ? '$number $symbol' : '$number $symbol $qualifier';
}

double _pow10(int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent.abs(); i++) {
    result *= 10;
  }
  return exponent < 0 ? 1 / result : result;
}
