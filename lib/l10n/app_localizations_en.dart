// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionOpenRecording => 'Open recording';

  @override
  String get actionRescan => 'Search again';

  @override
  String get availableMeters => 'Available meters';

  @override
  String get connectInstructions =>
      'Plug in the IR USB cable, attach it to the meter and switch the meter on. Meters are searched automatically.';

  @override
  String get scanFailed => 'Search failed';

  @override
  String noMeterFound(String models) {
    return 'No $models found';
  }

  @override
  String get noMeterFoundHint =>
      'Is the meter switched on and the IR adapter attached correctly? Then “Search again”.';

  @override
  String get searchingMeters => 'Searching for meters …';

  @override
  String get cablesWithoutMeter => 'Cables without meter';

  @override
  String get grantUsbCable => 'Allow USB cable …';

  @override
  String cableName(String name) {
    return 'Cable: $name';
  }

  @override
  String get modelUntested => 'Model not tested – display may be incomplete';

  @override
  String get actionConnect => 'Connect';

  @override
  String get openSavedRecording => 'Open saved recording';

  @override
  String get openSavedRecordingSubtitle =>
      'Show a CSV file, even without a meter';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get noMeterResponds => 'No meter responds';

  @override
  String get hintLibusbMissing =>
      'libusb is not installed (macOS: brew install libusb, Linux: apt install libusb-1.0-0, Windows: put libusb-1.0.dll next to the app).';

  @override
  String get hintDriverBusy =>
      'The cable is claimed by an operating system driver or permissions are missing. Linux: unbind ftdi_sio and add a udev rule; Windows: switch the cable to WinUSB with Zadig. See README.';

  @override
  String get hintNoWebUsb =>
      'This browser does not support WebUSB. Please use Chrome or Edge (HTTPS or localhost).';

  @override
  String get hintNoResponse =>
      'The meter does not respond. Is it switched on and the IR adapter attached correctly?';

  @override
  String get compactViewTooltip => 'Compact view (always on top)';

  @override
  String get actionDisconnect => 'Disconnect';

  @override
  String get notConnected => 'No connection to the meter';

  @override
  String get backToDeviceSelection => 'Back to device selection';

  @override
  String compactViewUnavailable(String error) {
    return 'Compact view not available: $error';
  }

  @override
  String get recordingStopTooltip => 'Stop recording';

  @override
  String get recordingStartTooltip => 'Start recording';

  @override
  String get recordingSaveOrDiscardFirst =>
      'Save or discard the recording first';

  @override
  String get dangerousVoltage => 'Hazardous voltage';

  @override
  String get rangeAuto => 'Auto';

  @override
  String get rangeManual => 'Manual';

  @override
  String minMaxSince(String time) {
    return 'Min Max since $time';
  }

  @override
  String get alwaysOnTopOff => 'Do not keep on top';

  @override
  String get alwaysOnTopOn => 'Always on top';

  @override
  String get normalView => 'Normal view';

  @override
  String get newRecording => 'New recording';

  @override
  String get recordingNameLabel => 'Recording name *';

  @override
  String get recordingNameRequired => 'Please enter a name';

  @override
  String get identifierLabel => 'Identifier';

  @override
  String get identifierHint => 'e.g. customer number';

  @override
  String get commentLabel => 'Comment';

  @override
  String get lengthLabel => 'Length *';

  @override
  String get lengthInvalid => 'Enter a length greater than 0';

  @override
  String get durationUnitLabel => 'Unit';

  @override
  String get unitSeconds => 'Seconds';

  @override
  String get unitMinutes => 'Minutes';

  @override
  String get unitHours => 'Hours';

  @override
  String get waitingForReadings => 'Waiting for readings …';

  @override
  String get history => 'Trend';

  @override
  String historyWithUnit(String unit) {
    return 'Trend – $unit';
  }

  @override
  String get timeBaseMeter => 'Meter time';

  @override
  String get timeBaseMeterTooltip => 'Timestamps of the meter';

  @override
  String get timeBaseSystem => 'System time';

  @override
  String get timeBaseSystemTooltip => 'Time this computer received the reading';

  @override
  String get axisClock => 'Time of day';

  @override
  String get axisTime => 'Time';

  @override
  String get axisTimeSeconds => 'Time [s]';

  @override
  String recordingActive(String name) {
    return 'Recording: $name';
  }

  @override
  String get actionStop => 'Stop';

  @override
  String sampleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count readings',
      one: '1 reading',
    );
    return '$_temp0';
  }

  @override
  String recordingSaved(String name) {
    return 'Recording “$name” saved';
  }

  @override
  String saveFailed(String error) {
    return 'Saving failed: $error';
  }

  @override
  String recordingFinished(String name) {
    return 'Recording “$name” finished';
  }

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionShow => 'Show';

  @override
  String get actionSave => 'Save';

  @override
  String get stopReasonStopped => 'Stopped early';

  @override
  String get stopReasonDisconnected => 'Meter disconnected';

  @override
  String get recording => 'Recording';

  @override
  String get noRecordingLoaded => 'No recording loaded';

  @override
  String get loadingFailed => 'Loading failed';

  @override
  String get recordingHasNoSamples => 'The recording contains no readings.';

  @override
  String get startMeter => 'Start (meter)';

  @override
  String get endMeter => 'End (meter)';

  @override
  String get startSystem => 'Start (system)';

  @override
  String get meterClockOffset => 'Meter clock vs. system';

  @override
  String get duration => 'Duration';

  @override
  String durationOf(String actual, String planned) {
    return '$actual of $planned';
  }

  @override
  String get readings => 'Readings';

  @override
  String get model => 'Model';

  @override
  String get serialNumber => 'Serial number';

  @override
  String get firmware => 'Firmware';

  @override
  String get endedLabel => 'Ended';

  @override
  String get statMinimum => 'Minimum';

  @override
  String get statMaximum => 'Maximum';

  @override
  String get statAverage => 'Average';

  @override
  String get overloadInvalid => 'OL / invalid';

  @override
  String recordingWithUnit(String unit) {
    return 'Recording – $unit';
  }

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomReset => 'Reset zoom';

  @override
  String get zoomHint =>
      'Mouse wheel or two-finger gesture to zoom, drag to pan';

  @override
  String get noValidReadings => 'No valid readings';

  @override
  String errorConnectionLost(String error) {
    return 'Connection lost: $error';
  }

  @override
  String get errorCableRemoved => 'The USB cable was disconnected.';

  @override
  String errorAckSyntax(String command) {
    return '$command: syntax error';
  }

  @override
  String errorAckExecution(String command) {
    return '$command: execution error';
  }

  @override
  String errorAckNoData(String command) {
    return '$command: no data available';
  }

  @override
  String errorAckUnexpected(String command, String response) {
    return '$command: unexpected response “$response”';
  }

  @override
  String errorNoResponse(String command) {
    return '$command: no response from the meter';
  }

  @override
  String errorInvalidData(String detail) {
    return 'Invalid data from the meter: $detail';
  }

  @override
  String get errorDeviceGone =>
      'Device no longer available, please search again.';

  @override
  String get errorDeviceInUse => 'The meter is already connected.';

  @override
  String errorOpenFile(String error) {
    return 'File could not be opened: $error';
  }

  @override
  String errorFileWithReason(String file, String error) {
    return '$file: $error';
  }

  @override
  String errorRecordingMissingColumn(String column) {
    return 'Invalid recording file: column “$column” is missing';
  }

  @override
  String get errorRecordingNoTable =>
      'Invalid recording file: no reading table found';

  @override
  String errorRecordingInvalidTime(int line) {
    return 'Invalid recording file: line $line has an invalid time';
  }

  @override
  String get fnTemperature => 'Temperature';

  @override
  String get fnResistance => 'Resistance';

  @override
  String get fnConductance => 'Conductance';

  @override
  String get fnContinuity => 'Continuity';

  @override
  String get fnCapacitance => 'Capacitance';

  @override
  String get fnDiodeTest => 'Diode test';

  @override
  String get fnFrequency => 'Frequency';

  @override
  String get fnDutyCycle => 'Duty cycle';

  @override
  String get fnPulseWidth => 'Pulse width';

  @override
  String get fnCrestFactor => 'Crest factor';

  @override
  String get modeLowPass => 'Low pass';

  @override
  String get modeRecord => 'Record';

  @override
  String get attrOpen => 'Open';

  @override
  String get attrShort => 'Short';

  @override
  String get attrGoodDiode => 'Good diode';

  @override
  String get attrNegativeEdge => 'Edge −';

  @override
  String get attrPositiveEdge => 'Edge +';

  @override
  String get attrHighCurrent => 'High current';

  @override
  String get readingPrimary => 'Primary';

  @override
  String get readingSecondary => 'Secondary';

  @override
  String get readingMinimum => 'Minimum';

  @override
  String get readingMaximum => 'Maximum';

  @override
  String get readingAverageShort => 'Avg';

  @override
  String get readingAverage => 'Average';

  @override
  String get readingRelReference => 'Rel reference';

  @override
  String get readingDbReference => 'dB reference';

  @override
  String get readingTempOffset => 'Temp offset';

  @override
  String get meterMemory => 'Meter memory';

  @override
  String get memoryRecordings => 'Recordings';

  @override
  String get memoryMinMax => 'Min/Max sessions';

  @override
  String get memoryPeak => 'Peak sessions';

  @override
  String get memoryMeasurements => 'Saved measurements';

  @override
  String get memoryEmpty => 'The meter memory is empty.';

  @override
  String get memoryReading => 'Reading meter memory …';

  @override
  String get memoryReadFailed => 'Reading the memory failed';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionDownload => 'Load';

  @override
  String get actionCancelDownload => 'Cancel download';

  @override
  String memoryInterval(String interval) {
    return 'Interval $interval';
  }

  @override
  String downloadProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get downloadCancelled => 'Download cancelled';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get unnamed => '(unnamed)';

  @override
  String get memoryDownloadHint =>
      'Recordings are read sample by sample; long recordings take a while.';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'Shows the live readings of Fluke 287 and 289 multimeters, records them and reads recordings from the meter memory.';

  @override
  String get version => 'Version';

  @override
  String get developer => 'Developer';

  @override
  String get sourceCode => 'Source code';

  @override
  String get license => 'License';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get openSourceLicensesHint => 'Licenses of all libraries used';

  @override
  String get disclaimer =>
      'Provided “as is”, without warranty. Do not rely on it for safety-relevant measurements.';

  @override
  String get trademarkNotice =>
      'Fluke is a trademark of Fluke Corporation. This project is not affiliated with or endorsed by Fluke Corporation.';

  @override
  String linkCouldNotOpen(String url) {
    return 'Could not open $url';
  }

  @override
  String get memoryNoEntries => 'No entries';

  @override
  String get originLabel => 'Source';

  @override
  String get originApp => 'Recorded by the app';

  @override
  String get originMeter => 'Meter memory';

  @override
  String get fileLabel => 'File';

  @override
  String get notSaved => 'Not saved';

  @override
  String get actionExportCsv => 'Export as CSV';

  @override
  String get sampleIntervalLabel => 'Interval';

  @override
  String get eventThresholdLabel => 'Event threshold';

  @override
  String get rangeLabel => 'Range';

  @override
  String recordingExported(String fileName) {
    return 'Exported as $fileName';
  }

  @override
  String aboutTooltip(String version) {
    return 'About · version $version';
  }

  @override
  String licenseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count licenses',
      one: '1 license',
    );
    return '$_temp0';
  }
}
