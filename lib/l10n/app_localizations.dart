import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionOpenRecording.
  ///
  /// In en, this message translates to:
  /// **'Open recording'**
  String get actionOpenRecording;

  /// No description provided for @actionRescan.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get actionRescan;

  /// No description provided for @availableMeters.
  ///
  /// In en, this message translates to:
  /// **'Available meters'**
  String get availableMeters;

  /// No description provided for @connectInstructions.
  ///
  /// In en, this message translates to:
  /// **'Plug in the IR USB cable, attach it to the meter and switch the meter on. Meters are searched automatically.'**
  String get connectInstructions;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get scanFailed;

  /// No description provided for @noMeterFound.
  ///
  /// In en, this message translates to:
  /// **'No {models} found'**
  String noMeterFound(String models);

  /// No description provided for @noMeterFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Is the meter switched on and the IR adapter attached correctly? Then “Search again”.'**
  String get noMeterFoundHint;

  /// No description provided for @searchingMeters.
  ///
  /// In en, this message translates to:
  /// **'Searching for meters …'**
  String get searchingMeters;

  /// No description provided for @cablesWithoutMeter.
  ///
  /// In en, this message translates to:
  /// **'Cables without meter'**
  String get cablesWithoutMeter;

  /// No description provided for @grantUsbCable.
  ///
  /// In en, this message translates to:
  /// **'Allow USB cable …'**
  String get grantUsbCable;

  /// No description provided for @cableName.
  ///
  /// In en, this message translates to:
  /// **'Cable: {name}'**
  String cableName(String name);

  /// No description provided for @modelUntested.
  ///
  /// In en, this message translates to:
  /// **'Model not tested – display may be incomplete'**
  String get modelUntested;

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get actionConnect;

  /// No description provided for @openSavedRecording.
  ///
  /// In en, this message translates to:
  /// **'Open saved recording'**
  String get openSavedRecording;

  /// No description provided for @openSavedRecordingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a CSV file, even without a meter'**
  String get openSavedRecordingSubtitle;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @noMeterResponds.
  ///
  /// In en, this message translates to:
  /// **'No meter responds'**
  String get noMeterResponds;

  /// No description provided for @hintLibusbMissing.
  ///
  /// In en, this message translates to:
  /// **'libusb is not installed (macOS: brew install libusb, Linux: apt install libusb-1.0-0, Windows: put libusb-1.0.dll next to the app).'**
  String get hintLibusbMissing;

  /// No description provided for @hintDriverBusy.
  ///
  /// In en, this message translates to:
  /// **'The cable is claimed by an operating system driver or permissions are missing. Linux: unbind ftdi_sio and add a udev rule; Windows: switch the cable to WinUSB with Zadig. See README.'**
  String get hintDriverBusy;

  /// No description provided for @hintNoWebUsb.
  ///
  /// In en, this message translates to:
  /// **'This browser does not support WebUSB. Please use Chrome or Edge (HTTPS or localhost).'**
  String get hintNoWebUsb;

  /// No description provided for @hintNoResponse.
  ///
  /// In en, this message translates to:
  /// **'The meter does not respond. Is it switched on and the IR adapter attached correctly?'**
  String get hintNoResponse;

  /// No description provided for @compactViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Compact view (always on top)'**
  String get compactViewTooltip;

  /// No description provided for @actionDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get actionDisconnect;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'No connection to the meter'**
  String get notConnected;

  /// No description provided for @backToDeviceSelection.
  ///
  /// In en, this message translates to:
  /// **'Back to device selection'**
  String get backToDeviceSelection;

  /// No description provided for @compactViewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Compact view not available: {error}'**
  String compactViewUnavailable(String error);

  /// No description provided for @recordingStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get recordingStopTooltip;

  /// No description provided for @recordingStartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordingStartTooltip;

  /// No description provided for @recordingSaveOrDiscardFirst.
  ///
  /// In en, this message translates to:
  /// **'Save or discard the recording first'**
  String get recordingSaveOrDiscardFirst;

  /// No description provided for @dangerousVoltage.
  ///
  /// In en, this message translates to:
  /// **'Hazardous voltage'**
  String get dangerousVoltage;

  /// No description provided for @rangeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get rangeAuto;

  /// No description provided for @rangeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get rangeManual;

  /// No description provided for @minMaxSince.
  ///
  /// In en, this message translates to:
  /// **'Min Max since {time}'**
  String minMaxSince(String time);

  /// No description provided for @alwaysOnTopOff.
  ///
  /// In en, this message translates to:
  /// **'Do not keep on top'**
  String get alwaysOnTopOff;

  /// No description provided for @alwaysOnTopOn.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get alwaysOnTopOn;

  /// No description provided for @normalView.
  ///
  /// In en, this message translates to:
  /// **'Normal view'**
  String get normalView;

  /// No description provided for @newRecording.
  ///
  /// In en, this message translates to:
  /// **'New recording'**
  String get newRecording;

  /// No description provided for @recordingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Recording name *'**
  String get recordingNameLabel;

  /// No description provided for @recordingNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get recordingNameRequired;

  /// No description provided for @identifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get identifierLabel;

  /// No description provided for @identifierHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. customer number'**
  String get identifierHint;

  /// No description provided for @commentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentLabel;

  /// No description provided for @lengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Length *'**
  String get lengthLabel;

  /// No description provided for @lengthInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a length greater than 0'**
  String get lengthInvalid;

  /// No description provided for @durationUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get durationUnitLabel;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get unitSeconds;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get unitMinutes;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get unitHours;

  /// No description provided for @waitingForReadings.
  ///
  /// In en, this message translates to:
  /// **'Waiting for readings …'**
  String get waitingForReadings;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get history;

  /// No description provided for @historyWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Trend – {unit}'**
  String historyWithUnit(String unit);

  /// No description provided for @timeBaseMeter.
  ///
  /// In en, this message translates to:
  /// **'Meter time'**
  String get timeBaseMeter;

  /// No description provided for @timeBaseMeterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Timestamps of the meter'**
  String get timeBaseMeterTooltip;

  /// No description provided for @timeBaseSystem.
  ///
  /// In en, this message translates to:
  /// **'System time'**
  String get timeBaseSystem;

  /// No description provided for @timeBaseSystemTooltip.
  ///
  /// In en, this message translates to:
  /// **'Time this computer received the reading'**
  String get timeBaseSystemTooltip;

  /// No description provided for @axisClock.
  ///
  /// In en, this message translates to:
  /// **'Time of day'**
  String get axisClock;

  /// No description provided for @axisTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get axisTime;

  /// No description provided for @axisTimeSeconds.
  ///
  /// In en, this message translates to:
  /// **'Time [s]'**
  String get axisTimeSeconds;

  /// No description provided for @recordingActive.
  ///
  /// In en, this message translates to:
  /// **'Recording: {name}'**
  String recordingActive(String name);

  /// No description provided for @actionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get actionStop;

  /// No description provided for @sampleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reading} other{{count} readings}}'**
  String sampleCount(int count);

  /// No description provided for @recordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording “{name}” saved'**
  String recordingSaved(String name);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @recordingFinished.
  ///
  /// In en, this message translates to:
  /// **'Recording “{name}” finished'**
  String recordingFinished(String name);

  /// No description provided for @actionDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// No description provided for @actionShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get actionShow;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @stopReasonStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped early'**
  String get stopReasonStopped;

  /// No description provided for @stopReasonDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Meter disconnected'**
  String get stopReasonDisconnected;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @noRecordingLoaded.
  ///
  /// In en, this message translates to:
  /// **'No recording loaded'**
  String get noRecordingLoaded;

  /// No description provided for @loadingFailed.
  ///
  /// In en, this message translates to:
  /// **'Loading failed'**
  String get loadingFailed;

  /// No description provided for @recordingHasNoSamples.
  ///
  /// In en, this message translates to:
  /// **'The recording contains no readings.'**
  String get recordingHasNoSamples;

  /// No description provided for @startMeter.
  ///
  /// In en, this message translates to:
  /// **'Start (meter)'**
  String get startMeter;

  /// No description provided for @endMeter.
  ///
  /// In en, this message translates to:
  /// **'End (meter)'**
  String get endMeter;

  /// No description provided for @startSystem.
  ///
  /// In en, this message translates to:
  /// **'Start (system)'**
  String get startSystem;

  /// No description provided for @meterClockOffset.
  ///
  /// In en, this message translates to:
  /// **'Meter clock vs. system'**
  String get meterClockOffset;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @durationOf.
  ///
  /// In en, this message translates to:
  /// **'{actual} of {planned}'**
  String durationOf(String actual, String planned);

  /// No description provided for @readings.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get readings;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @serialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get serialNumber;

  /// No description provided for @firmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get firmware;

  /// No description provided for @endedLabel.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get endedLabel;

  /// No description provided for @statMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get statMinimum;

  /// No description provided for @statMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get statMaximum;

  /// No description provided for @statAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get statAverage;

  /// No description provided for @overloadInvalid.
  ///
  /// In en, this message translates to:
  /// **'OL / invalid'**
  String get overloadInvalid;

  /// No description provided for @recordingWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Recording – {unit}'**
  String recordingWithUnit(String unit);

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomReset.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get zoomReset;

  /// No description provided for @zoomHint.
  ///
  /// In en, this message translates to:
  /// **'Mouse wheel or two-finger gesture to zoom, drag to pan'**
  String get zoomHint;

  /// No description provided for @noValidReadings.
  ///
  /// In en, this message translates to:
  /// **'No valid readings'**
  String get noValidReadings;

  /// No description provided for @errorConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost: {error}'**
  String errorConnectionLost(String error);

  /// No description provided for @errorCableRemoved.
  ///
  /// In en, this message translates to:
  /// **'The USB cable was disconnected.'**
  String get errorCableRemoved;

  /// No description provided for @errorAckSyntax.
  ///
  /// In en, this message translates to:
  /// **'{command}: syntax error'**
  String errorAckSyntax(String command);

  /// No description provided for @errorAckExecution.
  ///
  /// In en, this message translates to:
  /// **'{command}: execution error'**
  String errorAckExecution(String command);

  /// No description provided for @errorAckNoData.
  ///
  /// In en, this message translates to:
  /// **'{command}: no data available'**
  String errorAckNoData(String command);

  /// No description provided for @errorAckUnexpected.
  ///
  /// In en, this message translates to:
  /// **'{command}: unexpected response “{response}”'**
  String errorAckUnexpected(String command, String response);

  /// No description provided for @errorNoResponse.
  ///
  /// In en, this message translates to:
  /// **'{command}: no response from the meter'**
  String errorNoResponse(String command);

  /// No description provided for @errorInvalidData.
  ///
  /// In en, this message translates to:
  /// **'Invalid data from the meter: {detail}'**
  String errorInvalidData(String detail);

  /// No description provided for @errorDeviceGone.
  ///
  /// In en, this message translates to:
  /// **'Device no longer available, please search again.'**
  String get errorDeviceGone;

  /// No description provided for @errorDeviceInUse.
  ///
  /// In en, this message translates to:
  /// **'The meter is already connected.'**
  String get errorDeviceInUse;

  /// No description provided for @errorOpenFile.
  ///
  /// In en, this message translates to:
  /// **'File could not be opened: {error}'**
  String errorOpenFile(String error);

  /// No description provided for @errorFileWithReason.
  ///
  /// In en, this message translates to:
  /// **'{file}: {error}'**
  String errorFileWithReason(String file, String error);

  /// No description provided for @errorRecordingMissingColumn.
  ///
  /// In en, this message translates to:
  /// **'Invalid recording file: column “{column}” is missing'**
  String errorRecordingMissingColumn(String column);

  /// No description provided for @errorRecordingNoTable.
  ///
  /// In en, this message translates to:
  /// **'Invalid recording file: no reading table found'**
  String get errorRecordingNoTable;

  /// No description provided for @errorRecordingInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid recording file: line {line} has an invalid time'**
  String errorRecordingInvalidTime(int line);

  /// No description provided for @fnTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get fnTemperature;

  /// No description provided for @fnResistance.
  ///
  /// In en, this message translates to:
  /// **'Resistance'**
  String get fnResistance;

  /// No description provided for @fnConductance.
  ///
  /// In en, this message translates to:
  /// **'Conductance'**
  String get fnConductance;

  /// No description provided for @fnContinuity.
  ///
  /// In en, this message translates to:
  /// **'Continuity'**
  String get fnContinuity;

  /// No description provided for @fnCapacitance.
  ///
  /// In en, this message translates to:
  /// **'Capacitance'**
  String get fnCapacitance;

  /// No description provided for @fnDiodeTest.
  ///
  /// In en, this message translates to:
  /// **'Diode test'**
  String get fnDiodeTest;

  /// No description provided for @fnFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get fnFrequency;

  /// No description provided for @fnDutyCycle.
  ///
  /// In en, this message translates to:
  /// **'Duty cycle'**
  String get fnDutyCycle;

  /// No description provided for @fnPulseWidth.
  ///
  /// In en, this message translates to:
  /// **'Pulse width'**
  String get fnPulseWidth;

  /// No description provided for @fnCrestFactor.
  ///
  /// In en, this message translates to:
  /// **'Crest factor'**
  String get fnCrestFactor;

  /// No description provided for @modeLowPass.
  ///
  /// In en, this message translates to:
  /// **'Low pass'**
  String get modeLowPass;

  /// No description provided for @modeRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get modeRecord;

  /// No description provided for @attrOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get attrOpen;

  /// No description provided for @attrShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get attrShort;

  /// No description provided for @attrGoodDiode.
  ///
  /// In en, this message translates to:
  /// **'Good diode'**
  String get attrGoodDiode;

  /// No description provided for @attrNegativeEdge.
  ///
  /// In en, this message translates to:
  /// **'Edge −'**
  String get attrNegativeEdge;

  /// No description provided for @attrPositiveEdge.
  ///
  /// In en, this message translates to:
  /// **'Edge +'**
  String get attrPositiveEdge;

  /// No description provided for @attrHighCurrent.
  ///
  /// In en, this message translates to:
  /// **'High current'**
  String get attrHighCurrent;

  /// No description provided for @readingPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get readingPrimary;

  /// No description provided for @readingSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get readingSecondary;

  /// No description provided for @readingMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get readingMinimum;

  /// No description provided for @readingMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get readingMaximum;

  /// No description provided for @readingAverageShort.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get readingAverageShort;

  /// No description provided for @readingAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get readingAverage;

  /// No description provided for @readingRelReference.
  ///
  /// In en, this message translates to:
  /// **'Rel reference'**
  String get readingRelReference;

  /// No description provided for @readingDbReference.
  ///
  /// In en, this message translates to:
  /// **'dB reference'**
  String get readingDbReference;

  /// No description provided for @readingTempOffset.
  ///
  /// In en, this message translates to:
  /// **'Temp offset'**
  String get readingTempOffset;

  /// No description provided for @meterMemory.
  ///
  /// In en, this message translates to:
  /// **'Meter memory'**
  String get meterMemory;

  /// No description provided for @memoryRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get memoryRecordings;

  /// No description provided for @memoryMinMax.
  ///
  /// In en, this message translates to:
  /// **'Min/Max sessions'**
  String get memoryMinMax;

  /// No description provided for @memoryPeak.
  ///
  /// In en, this message translates to:
  /// **'Peak sessions'**
  String get memoryPeak;

  /// No description provided for @memoryMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Saved measurements'**
  String get memoryMeasurements;

  /// No description provided for @memoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'The meter memory is empty.'**
  String get memoryEmpty;

  /// No description provided for @memoryReading.
  ///
  /// In en, this message translates to:
  /// **'Reading meter memory …'**
  String get memoryReading;

  /// No description provided for @memoryReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Reading the memory failed'**
  String get memoryReadFailed;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionDownload.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get actionDownload;

  /// No description provided for @actionCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get actionCancelDownload;

  /// No description provided for @memoryInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval {interval}'**
  String memoryInterval(String interval);

  /// No description provided for @downloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String downloadProgress(int done, int total);

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get downloadCancelled;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'(unnamed)'**
  String get unnamed;

  /// No description provided for @memoryDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Recordings are read sample by sample; long recordings take a while.'**
  String get memoryDownloadHint;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows the live readings of Fluke 287 and 289 multimeters, records them and reads recordings from the meter memory.'**
  String get aboutDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @openSourceLicensesHint.
  ///
  /// In en, this message translates to:
  /// **'Licenses of all libraries used'**
  String get openSourceLicensesHint;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Provided “as is”, without warranty. Do not rely on it for safety-relevant measurements.'**
  String get disclaimer;

  /// No description provided for @trademarkNotice.
  ///
  /// In en, this message translates to:
  /// **'Fluke is a trademark of Fluke Corporation. This project is not affiliated with or endorsed by Fluke Corporation.'**
  String get trademarkNotice;

  /// No description provided for @linkCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String linkCouldNotOpen(String url);

  /// No description provided for @memoryNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries'**
  String get memoryNoEntries;

  /// No description provided for @originLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get originLabel;

  /// No description provided for @originApp.
  ///
  /// In en, this message translates to:
  /// **'Recorded by the app'**
  String get originApp;

  /// No description provided for @originMeter.
  ///
  /// In en, this message translates to:
  /// **'Meter memory'**
  String get originMeter;

  /// No description provided for @fileLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileLabel;

  /// No description provided for @notSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get notSaved;

  /// No description provided for @actionExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get actionExportCsv;

  /// No description provided for @sampleIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get sampleIntervalLabel;

  /// No description provided for @eventThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Event threshold'**
  String get eventThresholdLabel;

  /// No description provided for @rangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get rangeLabel;

  /// No description provided for @recordingExported.
  ///
  /// In en, this message translates to:
  /// **'Exported as {fileName}'**
  String recordingExported(String fileName);

  /// No description provided for @aboutTooltip.
  ///
  /// In en, this message translates to:
  /// **'About · version {version}'**
  String aboutTooltip(String version);

  /// No description provided for @licenseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 license} other{{count} licenses}}'**
  String licenseCount(int count);

  /// No description provided for @meterProperties.
  ///
  /// In en, this message translates to:
  /// **'Meter info'**
  String get meterProperties;

  /// No description provided for @propertyCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get propertyCompany;

  /// No description provided for @propertyOperator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get propertyOperator;

  /// No description provided for @propertySite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get propertySite;

  /// No description provided for @propertyContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get propertyContact;

  /// No description provided for @meterPropertiesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit meter info'**
  String get meterPropertiesEdit;

  /// No description provided for @meterPropertiesHint.
  ///
  /// In en, this message translates to:
  /// **'Saved in the meter. Letters without umlauts, digits and common symbols; no apostrophe.'**
  String get meterPropertiesHint;

  /// No description provided for @meterPropertiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing stored in the meter'**
  String get meterPropertiesEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
