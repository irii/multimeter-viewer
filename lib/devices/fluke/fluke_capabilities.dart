import '../../meter/model/meter_capabilities.dart';
import '../../meter/model/meter_identity.dart';

const _secondary = MeterSubFunctionKind.secondary;
const _mode = MeterSubFunctionKind.mode;

const _holdModes = [
  MeterSubFunction('HOLD', _mode),
  MeterSubFunction('AUTO_HOLD', _mode),
];

const _modes = [
  ..._holdModes,
  MeterSubFunction('MIN_MAX_AVG', _mode),
  MeterSubFunction('RECORD', _mode),
  MeterSubFunction('REL', _mode),
  MeterSubFunction('REL_PERCENT', _mode),
];

const _frequency = [
  MeterSubFunction('HERTZ', _secondary),
  MeterSubFunction('DUTY_CYCLE', _secondary),
  MeterSubFunction('PULSE_WIDTH', _secondary),
];

const _peak = MeterSubFunction('PEAK_MIN_MAX', _secondary);
const _crest = MeterSubFunction('CREST_FACTOR', _secondary);

const _voltageAc = [
  ..._frequency,
  MeterSubFunction('DBM', _secondary),
  MeterSubFunction('DBV', _secondary),
  MeterSubFunction('DBM_HERTZ', _secondary),
  MeterSubFunction('DBV_HERTZ', _secondary),
  _crest,
  _peak,
  ..._modes,
  MeterSubFunction('LOW_PASS_FILTER', _mode),
];

const _currentAc = [..._frequency, _crest, _peak, ..._modes];

/// Voltage and current with a DC part.
const _withDc = [..._frequency, _peak, ..._modes];

/// Only on the 289.
const _only289 = {'V_AC_LOZ', 'OHMS_LOW'};

const _measurements = [
  MeterCapability('V_AC', subFunctions: _voltageAc),
  MeterCapability('MV_AC', subFunctions: _voltageAc),
  MeterCapability('V_DC', subFunctions: _withDc),
  MeterCapability('MV_DC', subFunctions: _withDc),
  MeterCapability('V_AC_OVER_DC', subFunctions: _withDc),
  MeterCapability('V_DC_OVER_AC', subFunctions: _withDc),
  MeterCapability('V_AC_PLUS_DC', subFunctions: _withDc),
  MeterCapability('MV_AC_OVER_DC', subFunctions: _withDc),
  MeterCapability('MV_DC_OVER_AC', subFunctions: _withDc),
  MeterCapability('MV_AC_PLUS_DC', subFunctions: _withDc),
  MeterCapability('A_AC', subFunctions: _currentAc),
  MeterCapability('MA_AC', subFunctions: _currentAc),
  MeterCapability('UA_AC', subFunctions: _currentAc),
  MeterCapability('A_DC', subFunctions: _withDc),
  MeterCapability('MA_DC', subFunctions: _withDc),
  MeterCapability('UA_DC', subFunctions: _withDc),
  MeterCapability('A_AC_OVER_DC', subFunctions: _withDc),
  MeterCapability('A_DC_OVER_AC', subFunctions: _withDc),
  MeterCapability('A_AC_PLUS_DC', subFunctions: _withDc),
  MeterCapability('MA_AC_OVER_DC', subFunctions: _withDc),
  MeterCapability('MA_DC_OVER_AC', subFunctions: _withDc),
  MeterCapability('MA_AC_PLUS_DC', subFunctions: _withDc),
  MeterCapability('UA_AC_OVER_DC', subFunctions: _withDc),
  MeterCapability('UA_DC_OVER_AC', subFunctions: _withDc),
  MeterCapability('UA_AC_PLUS_DC', subFunctions: _withDc),
  MeterCapability('TEMPERATURE', subFunctions: _modes),
  MeterCapability('OHMS', subFunctions: _modes),
  MeterCapability('CONDUCTANCE', subFunctions: _modes),
  MeterCapability('CONTINUITY', subFunctions: _holdModes),
  MeterCapability('CAPACITANCE', subFunctions: _modes),
  MeterCapability('DIODE_TEST', subFunctions: _holdModes),
  MeterCapability('V_AC_LOZ', subFunctions: _voltageAc),
  MeterCapability('OHMS_LOW', subFunctions: _holdModes),
];

const _features = [
  MeterCapability(
    MeterFeatures.backlight,
    subFunctions: [
      MeterSubFunction(
        MeterFeatures.press,
        MeterSubFunctionKind.action,
        settable: true,
      ),
    ],
  ),
  MeterCapability(
    MeterFeatures.memory,
    subFunctions: [
      MeterSubFunction(MeterFeatures.read, MeterSubFunctionKind.action),
    ],
  ),
  MeterCapability(
    MeterFeatures.properties,
    subFunctions: [
      MeterSubFunction(MeterFeatures.read, MeterSubFunctionKind.action),
      MeterSubFunction(MeterFeatures.write, MeterSubFunctionKind.action),
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
