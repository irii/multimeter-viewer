// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settings => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionOpenRecording => 'Aufnahme öffnen';

  @override
  String get actionRescan => 'Neu suchen';

  @override
  String get availableMeters => 'Verfügbare Messgeräte';

  @override
  String get connectInstructions =>
      'IR-USB-Kabel anstecken, auf das Messgerät setzen und das Messgerät einschalten. Es wird automatisch gesucht.';

  @override
  String get scanFailed => 'Suche fehlgeschlagen';

  @override
  String noMeterFound(String models) {
    return 'Kein $models gefunden';
  }

  @override
  String get noMeterFoundHint =>
      'Ist das Messgerät eingeschaltet und sitzt der IR-Adapter richtig? Danach „Neu suchen“.';

  @override
  String get searchingMeters => 'Suche Messgeräte …';

  @override
  String get cablesWithoutMeter => 'Kabel ohne Messgerät';

  @override
  String get grantUsbCable => 'USB-Kabel freigeben …';

  @override
  String cableName(String name) {
    return 'Kabel: $name';
  }

  @override
  String get modelUntested =>
      'Modell nicht getestet – Anzeige kann unvollständig sein';

  @override
  String get actionConnect => 'Verbinden';

  @override
  String get openSavedRecording => 'Gespeicherte Aufnahme öffnen';

  @override
  String get openSavedRecordingSubtitle =>
      'CSV-Datei anzeigen, auch ohne Messgerät';

  @override
  String get connectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get noMeterResponds => 'Kein Messgerät antwortet';

  @override
  String get hintLibusbMissing =>
      'libusb ist nicht installiert (macOS: brew install libusb, Linux: apt install libusb-1.0-0, Windows: libusb-1.0.dll neben die App legen).';

  @override
  String get hintDriverBusy =>
      'Das Kabel ist von einem Betriebssystem-Treiber belegt oder es fehlen Rechte. Linux: ftdi_sio lösen und udev-Regel anlegen; Windows: Kabel per Zadig auf WinUSB umstellen. Siehe README.';

  @override
  String get hintNoWebUsb =>
      'Dieser Browser unterstützt kein WebUSB. Bitte Chrome oder Edge verwenden (HTTPS oder localhost).';

  @override
  String get hintNoResponse =>
      'Das Messgerät antwortet nicht. Ist es eingeschaltet und sitzt der IR-Adapter richtig?';

  @override
  String get compactViewTooltip => 'Kompaktansicht (immer im Vordergrund)';

  @override
  String get actionDisconnect => 'Trennen';

  @override
  String get notConnected => 'Keine Verbindung zum Messgerät';

  @override
  String get backToDeviceSelection => 'Zur Geräteauswahl';

  @override
  String compactViewUnavailable(String error) {
    return 'Kompaktansicht nicht möglich: $error';
  }

  @override
  String get recordingStopTooltip => 'Aufnahme stoppen';

  @override
  String get recordingStartTooltip => 'Aufnahme starten';

  @override
  String get recordingSaveOrDiscardFirst =>
      'Aufnahme erst speichern oder verwerfen';

  @override
  String get dangerousVoltage => 'Gefährliche Spannung';

  @override
  String get rangeAuto => 'Auto';

  @override
  String get rangeManual => 'Manuell';

  @override
  String minMaxSince(String time) {
    return 'Min Max seit $time';
  }

  @override
  String get alwaysOnTopOff => 'Nicht mehr im Vordergrund halten';

  @override
  String get alwaysOnTopOn => 'Immer im Vordergrund';

  @override
  String get normalView => 'Normale Ansicht';

  @override
  String get newRecording => 'Neue Aufnahme';

  @override
  String get recordingNameLabel => 'Name der Aufzeichnung *';

  @override
  String get recordingNameRequired => 'Bitte einen Namen eingeben';

  @override
  String get identifierLabel => 'Kennung';

  @override
  String get identifierHint => 'z. B. Kundennummer';

  @override
  String get commentLabel => 'Kommentar';

  @override
  String get lengthLabel => 'Länge *';

  @override
  String get lengthInvalid => 'Länge größer 0 eingeben';

  @override
  String get durationUnitLabel => 'Einheit';

  @override
  String get unitSeconds => 'Sekunden';

  @override
  String get unitMinutes => 'Minuten';

  @override
  String get unitHours => 'Stunden';

  @override
  String get waitingForReadings => 'Warte auf Messwerte …';

  @override
  String get history => 'Verlauf';

  @override
  String historyWithUnit(String unit) {
    return 'Verlauf – $unit';
  }

  @override
  String get timeBaseMeter => 'Gerätezeit';

  @override
  String get timeBaseMeterTooltip => 'Zeitstempel des Messgeräts';

  @override
  String get timeBaseSystem => 'Systemzeit';

  @override
  String get timeBaseSystemTooltip => 'Empfangszeit dieses Rechners';

  @override
  String get axisClock => 'Uhrzeit';

  @override
  String get axisTime => 'Zeit';

  @override
  String get axisTimeSeconds => 'Zeit [s]';

  @override
  String recordingActive(String name) {
    return 'Aufnahme: $name';
  }

  @override
  String get actionStop => 'Stopp';

  @override
  String sampleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Messwerte',
      one: '1 Messwert',
    );
    return '$_temp0';
  }

  @override
  String recordingSaved(String name) {
    return 'Aufnahme „$name“ gespeichert';
  }

  @override
  String saveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String recordingFinished(String name) {
    return 'Aufnahme „$name“ beendet';
  }

  @override
  String get actionDiscard => 'Verwerfen';

  @override
  String get actionShow => 'Anzeigen';

  @override
  String get actionSave => 'Speichern';

  @override
  String get stopReasonStopped => 'Vorzeitig beendet';

  @override
  String get stopReasonDisconnected => 'Verbindung zum Messgerät getrennt';

  @override
  String get recording => 'Aufnahme';

  @override
  String get noRecordingLoaded => 'Keine Aufnahme geladen';

  @override
  String get loadingFailed => 'Laden fehlgeschlagen';

  @override
  String get recordingHasNoSamples => 'Die Aufnahme enthält keine Messwerte.';

  @override
  String get startMeter => 'Start (Messgerät)';

  @override
  String get endMeter => 'Ende (Messgerät)';

  @override
  String get startSystem => 'Start (System)';

  @override
  String get meterClockOffset => 'Geräteuhr gegenüber System';

  @override
  String get duration => 'Dauer';

  @override
  String durationOf(String actual, String planned) {
    return '$actual von $planned';
  }

  @override
  String get readings => 'Messwerte';

  @override
  String get model => 'Modell';

  @override
  String get serialNumber => 'Seriennummer';

  @override
  String get firmware => 'Firmware';

  @override
  String get endedLabel => 'Beendet';

  @override
  String get statMinimum => 'Minimum';

  @override
  String get statMaximum => 'Maximum';

  @override
  String get statAverage => 'Mittelwert';

  @override
  String get overloadInvalid => 'OL / ungültig';

  @override
  String recordingWithUnit(String unit) {
    return 'Aufnahme – $unit';
  }

  @override
  String get zoomOut => 'Herauszoomen';

  @override
  String get zoomIn => 'Hineinzoomen';

  @override
  String get zoomReset => 'Zoom zurücksetzen';

  @override
  String get zoomHint =>
      'Mausrad oder Zwei-Finger-Geste zum Zoomen, ziehen zum Verschieben';

  @override
  String get noValidReadings => 'Keine gültigen Messwerte';

  @override
  String errorConnectionLost(String error) {
    return 'Verbindung verloren: $error';
  }

  @override
  String get errorCableRemoved => 'USB-Kabel wurde getrennt.';

  @override
  String errorAckSyntax(String command) {
    return '$command: Syntaxfehler';
  }

  @override
  String errorAckExecution(String command) {
    return '$command: Ausführungsfehler';
  }

  @override
  String errorAckNoData(String command) {
    return '$command: Keine Daten verfügbar';
  }

  @override
  String errorAckUnexpected(String command, String response) {
    return '$command: Unerwartete Antwort „$response“';
  }

  @override
  String errorNoResponse(String command) {
    return '$command: Keine Antwort vom Messgerät';
  }

  @override
  String errorInvalidData(String detail) {
    return 'Ungültige Daten vom Messgerät: $detail';
  }

  @override
  String get errorDeviceGone => 'Gerät nicht mehr vorhanden, bitte neu suchen.';

  @override
  String get errorDeviceInUse => 'Das Messgerät ist bereits verbunden.';

  @override
  String errorOpenFile(String error) {
    return 'Datei konnte nicht geöffnet werden: $error';
  }

  @override
  String errorFileWithReason(String file, String error) {
    return '$file: $error';
  }

  @override
  String errorRecordingMissingColumn(String column) {
    return 'Ungültige Aufnahme-Datei: Spalte „$column“ fehlt';
  }

  @override
  String get errorRecordingNoTable =>
      'Ungültige Aufnahme-Datei: Keine Messwert-Tabelle gefunden';

  @override
  String errorRecordingInvalidTime(int line) {
    return 'Ungültige Aufnahme-Datei: Zeile $line hat eine ungültige Zeit';
  }

  @override
  String get fnTemperature => 'Temperatur';

  @override
  String get fnResistance => 'Widerstand';

  @override
  String get fnConductance => 'Leitwert';

  @override
  String get fnContinuity => 'Durchgang';

  @override
  String get fnCapacitance => 'Kapazität';

  @override
  String get fnDiodeTest => 'Diodentest';

  @override
  String get fnFrequency => 'Frequenz';

  @override
  String get fnDutyCycle => 'Tastverhältnis';

  @override
  String get fnPulseWidth => 'Pulsbreite';

  @override
  String get fnCrestFactor => 'Crest-Faktor';

  @override
  String get modeLowPass => 'Tiefpass';

  @override
  String get modeRecord => 'Aufzeichnung';

  @override
  String get attrOpen => 'Offen';

  @override
  String get attrShort => 'Kurzschluss';

  @override
  String get attrGoodDiode => 'Diode OK';

  @override
  String get attrNegativeEdge => 'Flanke −';

  @override
  String get attrPositiveEdge => 'Flanke +';

  @override
  String get attrHighCurrent => 'Hoher Strom';

  @override
  String get readingPrimary => 'Primär';

  @override
  String get readingSecondary => 'Sekundär';

  @override
  String get readingMinimum => 'Minimum';

  @override
  String get readingMaximum => 'Maximum';

  @override
  String get readingAverageShort => 'Ø';

  @override
  String get readingAverage => 'Mittelwert';

  @override
  String get readingRelReference => 'Rel-Referenz';

  @override
  String get readingDbReference => 'dB-Referenz';

  @override
  String get readingTempOffset => 'Temp-Offset';

  @override
  String get meterMemory => 'Gerätespeicher';

  @override
  String get memoryRecordings => 'Aufzeichnungen';

  @override
  String get memoryMinMax => 'Min/Max-Sitzungen';

  @override
  String get memoryPeak => 'Peak-Sitzungen';

  @override
  String get memoryMeasurements => 'Gespeicherte Messwerte';

  @override
  String get memoryEmpty => 'Der Gerätespeicher ist leer.';

  @override
  String get memoryReading => 'Lese Gerätespeicher …';

  @override
  String get memoryReadFailed => 'Lesen des Speichers fehlgeschlagen';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get actionDownload => 'Laden';

  @override
  String get actionCancelDownload => 'Download abbrechen';

  @override
  String memoryInterval(String interval) {
    return 'Intervall $interval';
  }

  @override
  String downloadProgress(int done, int total) {
    return '$done von $total';
  }

  @override
  String get downloadCancelled => 'Download abgebrochen';

  @override
  String downloadFailed(String error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String get unnamed => '(ohne Name)';

  @override
  String get memoryDownloadHint =>
      'Aufzeichnungen werden Messwert für Messwert gelesen; lange Aufzeichnungen dauern etwas.';

  @override
  String get about => 'Über';

  @override
  String get aboutDescription =>
      'Zeigt die Live-Werte von Fluke-287- und -289-Multimetern an, zeichnet sie auf und liest Aufzeichnungen aus dem Gerätespeicher.';

  @override
  String get version => 'Version';

  @override
  String get developer => 'Entwickler';

  @override
  String get sourceCode => 'Quellcode';

  @override
  String get license => 'Lizenz';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get openSourceLicensesHint =>
      'Lizenzen aller verwendeten Bibliotheken';

  @override
  String get disclaimer =>
      'Bereitgestellt „wie besehen“, ohne Gewährleistung. Nicht für sicherheitsrelevante Messungen verwenden.';

  @override
  String get trademarkNotice =>
      'Fluke ist eine Marke der Fluke Corporation. Dieses Projekt steht in keiner Verbindung zur Fluke Corporation und wird von ihr weder unterstützt noch empfohlen.';

  @override
  String linkCouldNotOpen(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String get memoryNoEntries => 'Keine Einträge';

  @override
  String get originLabel => 'Quelle';

  @override
  String get originApp => 'Aufnahme der App';

  @override
  String get originMeter => 'Gerätespeicher des Messgeräts';

  @override
  String get fileLabel => 'Datei';

  @override
  String get notSaved => 'Nicht gespeichert';

  @override
  String get actionExportCsv => 'Als CSV exportieren';

  @override
  String get sampleIntervalLabel => 'Intervall';

  @override
  String get eventThresholdLabel => 'Ereignisschwelle';

  @override
  String get rangeLabel => 'Bereich';

  @override
  String recordingExported(String fileName) {
    return 'Exportiert als $fileName';
  }

  @override
  String aboutTooltip(String version) {
    return 'Über · Version $version';
  }

  @override
  String licenseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Lizenzen',
      one: '1 Lizenz',
    );
    return '$_temp0';
  }

  @override
  String get meterProperties => 'Geräteinfo';

  @override
  String get propertyCompany => 'Firma';

  @override
  String get propertyOperator => 'Bediener';

  @override
  String get propertySite => 'Standort';

  @override
  String get propertyContact => 'Kontakt';

  @override
  String get meterPropertiesEdit => 'Geräteinfo bearbeiten';

  @override
  String get meterPropertiesHint =>
      'Wird im Messgerät gespeichert. Buchstaben ohne Umlaute, Ziffern und gängige Zeichen; kein Apostroph.';

  @override
  String get meterPropertiesEmpty => 'Nichts im Gerät hinterlegt';
}
