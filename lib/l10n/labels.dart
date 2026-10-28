import 'package:intl/intl.dart';

import 'app_localizations.dart';

/// Identifiers that read the same in every language (`V AC`, `Hold`, ...)
/// are handled here as well, so callers need just one function.
extension FlukeLabels on AppLocalizations {
  String primaryFunction(String function) => switch (function) {
    'LIMBO' => '—',
    'V_AC' => 'V AC',
    'MV_AC' => 'mV AC',
    'V_DC' => 'V DC',
    'MV_DC' => 'mV DC',
    'V_AC_OVER_DC' => 'V AC/DC',
    'V_DC_OVER_AC' => 'V DC/AC',
    'V_AC_PLUS_DC' => 'V AC+DC',
    'MV_AC_OVER_DC' => 'mV AC/DC',
    'MV_DC_OVER_AC' => 'mV DC/AC',
    'MV_AC_PLUS_DC' => 'mV AC+DC',
    'A_AC' => 'A AC',
    'MA_AC' => 'mA AC',
    'UA_AC' => 'µA AC',
    'A_DC' => 'A DC',
    'MA_DC' => 'mA DC',
    'UA_DC' => 'µA DC',
    'A_AC_OVER_DC' => 'A AC/DC',
    'A_DC_OVER_AC' => 'A DC/AC',
    'A_AC_PLUS_DC' => 'A AC+DC',
    'MA_AC_OVER_DC' => 'mA AC/DC',
    'MA_DC_OVER_AC' => 'mA DC/AC',
    'MA_AC_PLUS_DC' => 'mA AC+DC',
    'UA_AC_OVER_DC' => 'µA AC/DC',
    'UA_DC_OVER_AC' => 'µA DC/AC',
    'UA_AC_PLUS_DC' => 'µA AC+DC',
    'TEMPERATURE' => fnTemperature,
    'OHMS' => fnResistance,
    'CONDUCTANCE' => fnConductance,
    'CONTINUITY' => fnContinuity,
    'CAPACITANCE' => fnCapacitance,
    'DIODE_TEST' => fnDiodeTest,
    'V_AC_LOZ' => 'V AC LoZ',
    'OHMS_LOW' => 'LoΩ',
    _ => _humanize(function),
  };

  String? secondaryFunction(String function) => switch (function) {
    'NONE' => null,
    'HERTZ' => fnFrequency,
    'DUTY_CYCLE' => fnDutyCycle,
    'PULSE_WIDTH' => fnPulseWidth,
    'DBM' => 'dBm',
    'DBV' => 'dBV',
    'DBM_HERTZ' => 'dBm / Hz',
    'DBV_HERTZ' => 'dBV / Hz',
    'CREST_FACTOR' => fnCrestFactor,
    'PEAK_MIN_MAX' => 'Peak Min/Max',
    _ => _humanize(function),
  };

  String mode(String mode) => switch (mode) {
    'AUTO_HOLD' => 'Auto Hold',
    'HOLD' => 'Hold',
    'LOW_PASS_FILTER' => modeLowPass,
    'MIN_MAX_AVG' => 'Min Max',
    'RECORD' => modeRecord,
    'REL' => 'Rel Δ',
    'REL_PERCENT' => 'Rel %',
    _ => _humanize(mode),
  };

  /// Name of a reading attribute, or `null` for `NONE`.
  String? attribute(String attribute) => switch (attribute) {
    'NONE' => null,
    'OPEN_CIRCUIT' => attrOpen,
    'SHORT_CIRCUIT' => attrShort,
    'GLITCH_CIRCUIT' => 'Glitch',
    'GOOD_DIODE' => attrGoodDiode,
    'LO_OHMS' => 'Lo Ω',
    'NEGATIVE_EDGE' => attrNegativeEdge,
    'POSITIVE_EDGE' || 'POSITIVE_ELDGE' => attrPositiveEdge,
    'HIGH_CURRENT' => attrHighCurrent,
    _ => _humanize(attribute),
  };

  String readingId(String id) => switch (id) {
    'LIVE' => 'Live',
    'PRIMARY' => readingPrimary,
    'SECONDARY' => readingSecondary,
    'REL_LIVE' => 'Rel Live',
    'BARGRAPH' => 'Bargraph',
    'MINIMUM' => readingMinimum,
    'MAXIMUM' => readingMaximum,
    'AVERAGE' => readingAverage,
    'REL_REFERENCE' => readingRelReference,
    'DB_REF' => readingDbReference,
    'TEMP_OFFSET' => readingTempOffset,
    _ => _humanize(id),
  };

  /// Short label for a reading in tight spaces, e.g. `Min`, `Ø`.
  String readingIdShort(String id) => switch (id) {
    'LIVE' => 'Live',
    'REL_LIVE' => 'Rel',
    'MINIMUM' => 'Min',
    'MAXIMUM' => 'Max',
    'AVERAGE' => readingAverageShort,
    'REL_REFERENCE' => 'Ref',
    'DB_REF' => 'dB Ref',
    'TEMP_OFFSET' => 'Offset',
    _ => readingId(id),
  };

  /// Date and time in the locale's format, e.g. `28.10.2026 14:05:00` or
  /// `10/28/2026 2:05:00 PM`.
  String dateTime(DateTime t) => DateFormat.yMd(localeName).add_Hms().format(t);

  /// Time of day, e.g. `14:05:00`.
  String timeOfDay(DateTime t) => DateFormat.Hms(localeName).format(t);

  /// A decimal number with the locale's separator, e.g. `2,4` / `2.4`.
  String decimal(double value, int fractionDigits) =>
      NumberFormat.decimalPatternDigits(
        locale: localeName,
        decimalDigits: fractionDigits,
      ).format(value);
}

String _humanize(String id) => id.replaceAll('_', ' ');
