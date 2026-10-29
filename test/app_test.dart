import 'package:multimeter_viewer/app.dart';
import 'package:multimeter_viewer/bloc/time_base_cubit.dart';
import 'package:multimeter_viewer/fluke/meter_discovery.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:multimeter_viewer/recording/recording_csv.dart';
import 'package:multimeter_viewer/ui/recording_page.dart';
import 'package:multimeter_viewer/ui/meter_page.dart';
import 'package:multimeter_viewer/ui/widgets/meter_properties_card.dart';
import 'package:multimeter_viewer/ui/widgets/primary_display.dart';
import 'package:multimeter_viewer/fluke/meter_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'recording_csv_test.dart' show sampleRecording;

void main() {
  testWidgets('lists meters, connects, records and disconnects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: FakeDiscovery(),
      ),
    );
    await tester.pumpAndSettle();

    // Discovered meter is listed with its identity.
    expect(find.text('FLUKE 289'), findsOneWidget);
    expect(find.textContaining('SN 40211337'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(MeterPage), findsOneWidget);
    expect(find.text(' 7.312'), findsOneWidget);
    expect(find.textContaining('Verlauf'), findsOneWidget);

    // Time base toggle of the live chart.
    expect(find.text('Gerätezeit'), findsOneWidget);
    TimeBase timeBase() =>
        tester.element(find.byType(MeterPage)).read<TimeBaseCubit>().state;
    expect(timeBase(), TimeBase.meter);
    await tester.tap(find.text('Systemzeit'));
    await tester.pumpAndSettle();
    expect(timeBase(), TimeBase.system);
    expect(find.text('Uhrzeit'), findsOneWidget);

    // Recording dialog validates and starts a recording.
    await tester.tap(find.byTooltip('Aufnahme starten'));
    await tester.pumpAndSettle();
    expect(find.text('Neue Aufnahme'), findsOneWidget);
    await tester.tap(find.text('Aufnahme starten'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte einen Namen eingeben'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name der Aufzeichnung *'),
      'Motor A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kennung'),
      'K-4711',
    );
    await tester.tap(find.text('Aufnahme starten'));
    await tester.pumpAndSettle();
    expect(find.text('Aufnahme: Motor A (K-4711)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Aufnahme stoppen'));
    await tester.pumpAndSettle();
    expect(find.text('Aufnahme „Motor A“ beendet'), findsOneWidget);

    // The finished recording opens in its own chart page.
    await tester.tap(find.text('Anzeigen'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordingPage), findsOneWidget);
    expect(find.text('K-4711'), findsOneWidget);
    expect(find.text('40211337'), findsOneWidget);
    expect(find.text('Aufnahme – V AC'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MeterPage), findsOneWidget);

    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Trennen'));
    await tester.pumpAndSettle();
    expect(find.byType(MeterPage), findsNothing);
    expect(find.text('Verfügbare Messgeräte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows hint when no meter is found', (tester) async {
    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: FakeDiscovery(candidates: const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kein Fluke 287/289 gefunden'), findsOneWidget);
  });

  testWidgets('opens a recording file without a meter connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,

        discovery: FakeDiscovery(candidates: const []),
        pickRecordingFile: () async =>
            (name: 'motor.csv', content: recordingToCsv(sampleRecording())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gespeicherte Aufnahme öffnen'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordingPage), findsOneWidget);
    expect(find.text('Motor A'), findsOneWidget);
    expect(find.text('FLUKE 289'), findsOneWidget);
    expect(find.text('40211337'), findsOneWidget);
    expect(find.text('motor.csv'), findsOneWidget);
    expect(find.text('Aufnahme – V AC'), findsOneWidget);
    expect(find.text('Ende (Messgerät)'), findsOneWidget);
    expect(find.text('Start (System)'), findsOneWidget);
    expect(find.text('Geräteuhr gegenüber System'), findsOneWidget);

    // Zoom buttons.
    expect(find.text('1.0×'), findsOneWidget);
    await tester.tap(find.byTooltip('Hineinzoomen'));
    await tester.pumpAndSettle();
    expect(find.text('2.0×'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('1.0×'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Verfügbare Messgeräte'), findsOneWidget);
  });

  testWidgets('lists and connects a Fluke 287 next to a 289', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const unknownCandidate = MeterCandidate(
      id: '403:6001:C9',
      cableName: 'FT232R (C9)',
      identity: MeterIdentity(model: 'FLUKE 999', firmware: 'V1', serial: '9'),
    );
    final discovery = FakeDiscovery(
      candidates: const [fakeCandidate, fake287Candidate, unknownCandidate],
      link: FakeLink(meterIdentity: fluke287Identity),
    );
    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: discovery,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Multimeter Viewer'), findsOneWidget);
    expect(find.text('FLUKE 289'), findsOneWidget);
    expect(find.text('FLUKE 287'), findsOneWidget);
    expect(find.textContaining('Modell nicht getestet'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'FLUKE 287'),
        matching: find.widgetWithText(FilledButton, 'Verbinden'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(MeterPage), findsOneWidget);
    expect(find.text('FLUKE 287'), findsOneWidget);
    expect(find.text('FW V2.02 · SN 12345678'), findsOneWidget);
    expect(find.text(' 7.312'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('desktop: live display and meter info are equally tall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: FakeDiscovery(
          link: FakeLink(
            properties: const MeterProperties(
              company: 'ACME',
              operator: 'Max Muster',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final live = tester.getRect(find.byType(PrimaryDisplay));
    final info = tester.getRect(find.byType(MeterPropertiesCard));
    expect(info.height, live.height);
    expect(info.top, live.top);
    expect(find.text('Max Muster'), findsOneWidget);

    // Edit, save, and the page still reacts.
    await tester.tap(find.byTooltip('Geräteinfo bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Standort'),
      'Halle 3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Halle 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Geräteinfo bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('phone width: secondary actions move into the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: FakeDiscovery(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Einstellungen'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(MeterPage), findsOneWidget);
    expect(tester.takeException(), isNull); // app bar fits

    expect(find.byTooltip('Aufnahme starten'), findsOneWidget);
    expect(find.byTooltip('Gerätespeicher'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    for (final entry in [
      'Gerätespeicher',
      'Aufnahme öffnen',
      'Trennen',
      'Einstellungen',
      'Über',
    ]) {
      expect(find.text(entry), findsOneWidget, reason: entry);
    }
    await tester.tap(find.text('Trennen'));
    await tester.pumpAndSettle();
    expect(find.text('Verfügbare Messgeräte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
