import '../../meter/model/meter_capabilities.dart';
import '../../meter/model/meter_identity.dart';

const _toggle = MeterControl.toggle;
const _secondary = MeterStateSource.secondaryFunction;
const _mode = MeterStateSource.mode;

const _holdModes = [
  MeterSubCapability('HOLD', _toggle, source: _mode),
  MeterSubCapability('AUTO_HOLD', _toggle, source: _mode),
];

const _modes = [
  ..._holdModes,
  MeterSubCapability('MIN_MAX_AVG', _toggle, source: _mode),
  MeterSubCapability('RECORD', _toggle, source: _mode),
  MeterSubCapability('REL', _toggle, source: _mode),
  MeterSubCapability('REL_PERCENT', _toggle, source: _mode),
];

const _frequency = [
  MeterSubCapability('HERTZ', _toggle, source: _secondary),
  MeterSubCapability('DUTY_CYCLE', _toggle, source: _secondary),
  MeterSubCapability('PULSE_WIDTH', _toggle, source: _secondary),
];

const _peak = MeterSubCapability('PEAK_MIN_MAX', _toggle, source: _secondary);
const _crest = MeterSubCapability('CREST_FACTOR', _toggle, source: _secondary);

const _voltageAc = [
  ..._frequency,
  MeterSubCapability('DBM', _toggle, source: _secondary),
  MeterSubCapability('DBV', _toggle, source: _secondary),
  MeterSubCapability('DBM_HERTZ', _toggle, source: _secondary),
  MeterSubCapability('DBV_HERTZ', _toggle, source: _secondary),
  _crest,
  _peak,
  ..._modes,
  MeterSubCapability('LOW_PASS_FILTER', _toggle, source: _mode),
];

const _currentAc = [..._frequency, _crest, _peak, ..._modes];

/// Voltage and current with a DC part.
const _withDc = [..._frequency, _peak, ..._modes];

/// Only on the 289.
const _only289 = {'V_AC_LOZ', 'OHMS_LOW'};

const _measurements = [
  MeterCapability('V_AC', subCapabilities: _voltageAc),
  MeterCapability('MV_AC', subCapabilities: _voltageAc),
  MeterCapability('V_DC', subCapabilities: _withDc),
  MeterCapability('MV_DC', subCapabilities: _withDc),
  MeterCapability('V_AC_OVER_DC', subCapabilities: _withDc),
  MeterCapability('V_DC_OVER_AC', subCapabilities: _withDc),
  MeterCapability('V_AC_PLUS_DC', subCapabilities: _withDc),
  MeterCapability('MV_AC_OVER_DC', subCapabilities: _withDc),
  MeterCapability('MV_DC_OVER_AC', subCapabilities: _withDc),
  MeterCapability('MV_AC_PLUS_DC', subCapabilities: _withDc),
  MeterCapability('A_AC', subCapabilities: _currentAc),
  MeterCapability('MA_AC', subCapabilities: _currentAc),
  MeterCapability('UA_AC', subCapabilities: _currentAc),
  MeterCapability('A_DC', subCapabilities: _withDc),
  MeterCapability('MA_DC', subCapabilities: _withDc),
  MeterCapability('UA_DC', subCapabilities: _withDc),
  MeterCapability('A_AC_OVER_DC', subCapabilities: _withDc),
  MeterCapability('A_DC_OVER_AC', subCapabilities: _withDc),
  MeterCapability('A_AC_PLUS_DC', subCapabilities: _withDc),
  MeterCapability('MA_AC_OVER_DC', subCapabilities: _withDc),
  MeterCapability('MA_DC_OVER_AC', subCapabilities: _withDc),
  MeterCapability('MA_AC_PLUS_DC', subCapabilities: _withDc),
  MeterCapability('UA_AC_OVER_DC', subCapabilities: _withDc),
  MeterCapability('UA_DC_OVER_AC', subCapabilities: _withDc),
  MeterCapability('UA_AC_PLUS_DC', subCapabilities: _withDc),
  MeterCapability('TEMPERATURE', subCapabilities: _modes),
  MeterCapability('OHMS', subCapabilities: _modes),
  MeterCapability('CONDUCTANCE', subCapabilities: _modes),
  MeterCapability('CONTINUITY', subCapabilities: _holdModes),
  MeterCapability('CAPACITANCE', subCapabilities: _modes),
  MeterCapability('DIODE_TEST', subCapabilities: _holdModes),
  MeterCapability('V_AC_LOZ', subCapabilities: _voltageAc),
  MeterCapability('OHMS_LOW', subCapabilities: _holdModes),
];

const _features = [
  MeterCapability(
    'backlight',
    subCapabilities: [
      MeterSubCapability('press', MeterControl.button, settable: true),
    ],
  ),
  MeterCapability(
    MeterFeatures.memory,
    subCapabilities: [
      MeterSubCapability(MeterFeatures.read, MeterControl.none),
    ],
  ),
  MeterCapability(
    MeterFeatures.properties,
    subCapabilities: [
      MeterSubCapability(MeterFeatures.read, MeterControl.none),
      MeterSubCapability(MeterFeatures.write, MeterControl.none),
    ],
  ),
];

/// What the meter of [identity] can do. The rotary switch and the buttons of
/// the meter set its modes; the app can only show them. The one thing it can
/// set is the backlight.
MeterCapabilities flukeCapabilities(MeterIdentity identity) =>
    MeterCapabilities(
      measurements: identity.meterModel == MeterModel.fluke287
          ? [
              for (final measurement in _measurements)
                if (!_only289.contains(measurement.id)) measurement,
            ]
          : _measurements,
      features: _features,
    );
