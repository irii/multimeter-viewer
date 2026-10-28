import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/about/app_info.dart';
import 'package:multimeter_viewer/app.dart';
import 'package:multimeter_viewer/bloc/memory_bloc.dart';
import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/fluke/fluke_memory_reader.dart';
import 'package:multimeter_viewer/fluke/qdda.dart';
import 'package:multimeter_viewer/recording/recording.dart';
import 'package:multimeter_viewer/ui/about_page.dart';
import 'package:multimeter_viewer/ui/licenses_page.dart';
import 'package:multimeter_viewer/ui/widgets/window_app_bar.dart';
import 'package:multimeter_viewer/ui/settings_dialog.dart';
import 'package:multimeter_viewer/ui/memory_page.dart';
import 'package:multimeter_viewer/ui/recording_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'recording_csv_test.dart' show sampleRecording;

const _range = RangeData(
  autoRange: true,
  baseUnit: 'VDC',
  rangeNumber: 5,
  multiplier: 0,
);

final memoryRecording = MemoryRecording(
  index: 0,
  name: 'Battery 1',
  start: dateTimeToMeterTime(DateTime(2026, 10, 28, 14, 5)),
  end: dateTimeToMeterTime(DateTime(2026, 10, 28, 14, 35)),
  sampleInterval: 15,
  eventThreshold: 0.04,
  readingIndex: 7,
  sampleCount: 2,
  primaryFunction: 'V_DC',
  secondaryFunction: 'NONE',
  range: _range,
  modes: const ['RECORD'],
  readings: const [],
);

const _reading = Reading(
  id: 'MAXIMUM',
  value: 1.5,
  baseUnit: 'VDC',
  multiplier: 0,
  decimalPlaces: 4,
  displayDigits: 5,
  state: 'NORMAL',
  attribute: 'NONE',
  timestamp: 1761660300,
);

final contents = MemoryContents(
  recordings: [memoryRecording],
  minMaxSessions: [
    MemorySession(
      kind: MemorySessionKind.minMax,
      index: 0,
      name: 'Motor',
      start: 1761660300,
      end: 1761660900,
      primaryFunction: 'V_DC',
      secondaryFunction: 'NONE',
      range: _range,
      modes: const ['MIN_MAX_AVG'],
      readings: const [_reading],
    ),
  ],
  measurements: const [
    MemoryMeasurement(
      index: 0,
      name: 'Save 1',
      primaryFunction: 'V_DC',
      secondaryFunction: 'NONE',
      range: _range,
      modes: [],
      readings: [_reading],
    ),
  ],
);

void main() {
  late FakeMemory memory;

  MemoryBloc build() => MemoryBloc(memory: memory);

  setUp(
    () => memory = FakeMemory(contents: contents, recording: sampleRecording()),
  );

  blocTest<MemoryBloc, MemoryState>(
    'loads the memory contents',
    build: build,
    act: (bloc) => bloc.add(const MemoryLoadRequested()),
    expect: () => [
      const MemoryState(),
      MemoryState(status: MemoryStatus.loaded, contents: contents),
    ],
  );

  blocTest<MemoryBloc, MemoryState>(
    'reports read errors',
    build: () {
      memory.readError = const FlukeTimeoutException('qsls');
      return build();
    },
    act: (bloc) => bloc.add(const MemoryLoadRequested()),
    verify: (bloc) {
      expect(bloc.state.status, MemoryStatus.failure);
      expect(bloc.state.error, const FlukeTimeoutException('qsls'));
    },
  );

  blocTest<MemoryBloc, MemoryState>(
    'downloads a recording with progress',
    build: build,
    act: (bloc) => bloc.add(MemoryDownloadRequested(memoryRecording)),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.downloading, isNull);
      expect(bloc.state.downloaded, sampleRecording());
      expect(bloc.state.downloadCount, 1);
      expect(bloc.state.downloadDone, 2);
    },
  );

  blocTest<MemoryBloc, MemoryState>(
    'cancels a download',
    build: () {
      memory.sampleDelay = const Duration(milliseconds: 20);
      return build();
    },
    act: (bloc) async {
      bloc.add(MemoryDownloadRequested(memoryRecording));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(const MemoryDownloadCancelRequested());
    },
    wait: const Duration(milliseconds: 60),
    verify: (bloc) {
      expect(bloc.state.downloadCancelled, isTrue);
      expect(bloc.state.downloaded, isNull);
      expect(bloc.state.downloading, isNull);
    },
  );

  testWidgets('memory page lists the memory and charts a download', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final discovery = FakeDiscovery();
    final sample = sampleRecording();
    discovery.link.memory = FakeMemory(
      contents: contents,
      recording: Recording(
        info: sample.info,
        startedAt: sample.startedAt,
        duration: sample.duration,
        samples: sample.samples,
        identity: sample.identity,
        origin: RecordingOrigin.meter,
      ),
    );
    await tester.pumpWidget(
      MultimeterViewerApp(
        discovery: discovery,
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Gerätespeicher'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryPage), findsOneWidget);
    expect(find.text('Aufzeichnungen (1)'), findsOneWidget);
    expect(find.text('Battery 1'), findsOneWidget);
    expect(find.text('Min/Max-Sitzungen (1)'), findsOneWidget);
    expect(find.text('Peak-Sitzungen (0)'), findsOneWidget);
    expect(find.text('Keine Einträge'), findsOneWidget);
    expect(find.text('Gespeicherte Messwerte (1)'), findsOneWidget);

    // Expanding a session shows its readings.
    await tester.tap(find.text('Motor'));
    await tester.pumpAndSettle();
    expect(find.text(' 1.5000 V DC'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Laden'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordingPage), findsOneWidget);
    expect(find.text('Gerätespeicher des Messgeräts'), findsOneWidget);
    expect(find.text('Nicht gespeichert'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('about page names developer, repository and license', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultimeterViewerApp(
        discovery: FakeDiscovery(),
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Über · Version ${AppInfo.version}'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('Ivan Radeljak'), findsOneWidget);
    expect(find.text('github.com/irii/multimeter-viewer'), findsOneWidget);
    expect(find.text('MIT · © 2026 Ivan Radeljak'), findsOneWidget);
    expect(find.textContaining('Marke der Fluke Corporation'), findsOneWidget);
    expect(find.text('Danksagung'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('open-source licenses use the app pages', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(['testlib'], 'Test license text'),
      ),
    );
    addTearDown(LicenseRegistry.reset);
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultimeterViewerApp(
        discovery: FakeDiscovery(),
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Über · Version ${AppInfo.version}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open-Source-Lizenzen'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensesPage), findsOneWidget);
    expect(find.byType(WindowAppBar), findsOneWidget);
    await tester.tap(find.text('testlib'));
    await tester.pumpAndSettle();
    expect(find.text('Test license text'), findsOneWidget);
    expect(find.byType(WindowAppBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('app menu opens about page and settings in the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultimeterViewerApp(
        discovery: FakeDiscovery(),
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> menu(String command) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'multimeter_viewer/menu',
        const StandardMethodCodec().encodeMethodCall(MethodCall(command)),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await menu('settings');
    expect(find.byType(SettingsDialog), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await menu('about');
    expect(find.byType(AboutPage), findsOneWidget);
    await menu('about'); // already shown: not pushed twice
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  test('app version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+?)(\+\d+)?$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(AppInfo.version, version);
  });

  test('LICENSE names the developer', () {
    final license = File('LICENSE').readAsStringSync();
    expect(license, startsWith('MIT License'));
    expect(license, contains('Copyright (c) 2026 Ivan Radeljak'));
  });
}
