import 'package:multimeter_viewer/app.dart';
import 'package:multimeter_viewer/fluke/meter_discovery.dart';
import 'package:multimeter_viewer/ui/meter_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const second = MeterCandidate(
  id: '403:6001:B7',
  cableName: 'FT232R (B7)',
  identity: fluke287Identity,
);

Future<void> start(WidgetTester tester, FakeDiscovery discovery) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultimeterViewerApp(
      discovery: discovery,
      settingsStore: MemorySettingsStore(),
      initialSettings: germanSettings,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('Android: connects automatically to the only meter', (
    tester,
  ) async {
    await start(tester, FakeDiscovery()..autoSelectSingle = true);
    expect(find.byType(MeterPage), findsOneWidget);
    expect(find.text(' 7.312'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('no automatic connection with two meters', (tester) async {
    await start(
      tester,
      FakeDiscovery(candidates: const [fakeCandidate, second])
        ..autoSelectSingle = true,
    );
    expect(find.byType(MeterPage), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Verbinden'), findsNWidgets(2));
    await finish(tester);
  });

  testWidgets('desktop/web: no automatic connection', (tester) async {
    await start(tester, FakeDiscovery());
    expect(find.byType(MeterPage), findsNothing);
    await finish(tester);
  });

  testWidgets('after a manual disconnect only a re-plugged meter reconnects', (
    tester,
  ) async {
    final discovery = FakeDiscovery()..autoSelectSingle = true;
    await start(tester, discovery);
    expect(find.byType(MeterPage), findsOneWidget);

    await tester.tap(find.byTooltip('Trennen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    // Stays on the device list although the meter is still there.
    expect(find.byType(MeterPage), findsNothing);
    expect(find.text('FLUKE 289'), findsOneWidget);

    // Cable unplugged ...
    discovery.candidates = const [];
    discovery.changes.add(null);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Kein Fluke 287/289 gefunden'), findsOneWidget);

    // ... and plugged in again: connects.
    discovery.candidates = const [fakeCandidate];
    discovery.changes.add(null);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(MeterPage), findsOneWidget);
    await finish(tester);
  });
}
