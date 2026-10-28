import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/app.dart';
import 'package:multimeter_viewer/compact/compact_mode_cubit.dart';
import 'package:multimeter_viewer/ui/compact_page.dart';
import 'package:multimeter_viewer/ui/meter_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeCompactWindow window;

  blocTest<CompactModeCubit, CompactModeState>(
    'enter, toggle always-on-top, exit',
    build: () => CompactModeCubit(window = FakeCompactWindow()),
    act: (cubit) async {
      await cubit.enter();
      await cubit.enter(); // no-op while active
      await cubit.toggleAlwaysOnTop();
      await cubit.exit();
    },
    expect: () => const [
      CompactModeState(active: true, alwaysOnTop: true),
      CompactModeState(active: true),
      CompactModeState(),
    ],
    verify: (_) => expect(window.calls, ['enter', 'onTop:false', 'exit']),
  );

  test('unavailable without a compact window', () async {
    final cubit = CompactModeCubit(null);
    expect(cubit.available, isFalse);
    await cubit.enter();
    expect(cubit.state.active, isFalse);
  });

  Future<void> connect(WidgetTester tester, FakeDiscovery discovery) async {
    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: discovery,
        compactWindow: window,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('switches to the compact panel and back', (tester) async {
    window = FakeCompactWindow();
    await connect(tester, FakeDiscovery());

    await tester.tap(find.byTooltip('Kompaktansicht (immer im Vordergrund)'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactPage), findsOneWidget);
    expect(find.text('  7.312'), findsOneWidget);
    expect(find.text('mV AC'), findsNWidgets(2)); // function + unit
    // The live value equals the main value, so it is not repeated.
    expect(find.text('Live'), findsNothing);
    expect(window.calls, ['enter']);

    await tester.tap(find.byTooltip('Nicht mehr im Vordergrund halten'));
    await tester.pumpAndSettle();
    expect(window.calls, ['enter', 'onTop:false']);

    await tester.tap(find.byTooltip('Normale Ansicht'));
    await tester.pumpAndSettle();
    expect(find.byType(MeterPage), findsOneWidget);
    expect(window.calls.last, 'exit');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows min/max/avg small below the main value', (tester) async {
    window = FakeCompactWindow();
    await connect(
      tester,
      FakeDiscovery(link: FakeLink(responses: [sampleQddaMinMax])),
    );

    await tester.tap(find.byTooltip('Kompaktansicht (immer im Vordergrund)'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactPage), findsOneWidget);
    for (final label in ['Min', 'Max', 'Ø']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('-18.70 mV'), findsOneWidget);
    expect(find.text(' 27.64 mV'), findsOneWidget);
    expect(tester.takeException(), isNull); // no overflow

    // Default panel size: still one line, no overflow.
    tester.view.physicalSize = const Size(360, 170);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    expect(find.text('Min'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Smallest panel and a picture-in-picture sized one: everything is
    // still shown, just scaled down.
    for (final size in const [Size(220, 110), Size(200, 100)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('-18.70 mV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('picture-in-picture: no buttons, closing returns to the meter', (
    tester,
  ) async {
    window = FakeCompactWindow(hasControls: false);
    await connect(tester, FakeDiscovery());

    await tester.tap(find.byTooltip('Kompaktansicht (immer im Vordergrund)'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactPage), findsOneWidget);
    expect(find.text('  7.312'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);

    // The user expands or closes the picture-in-picture window.
    window.closedBySystem.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(MeterPage), findsOneWidget);
    expect(window.calls, ['enter']); // the system already left it

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('disconnect restores the normal window', (tester) async {
    window = FakeCompactWindow();
    final discovery = FakeDiscovery();
    await connect(tester, discovery);

    await tester.tap(find.byTooltip('Kompaktansicht (immer im Vordergrund)'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactPage), findsOneWidget);

    discovery.link.removed.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(CompactPage), findsNothing);
    expect(find.text('Verfügbare Messgeräte'), findsOneWidget);
    expect(window.calls, ['enter', 'exit']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no compact button without a compact window (iOS, web)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultimeterViewerApp(
        settingsStore: MemorySettingsStore(),
        initialSettings: germanSettings,
        discovery: FakeDiscovery(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Kompaktansicht (immer im Vordergrund)'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
