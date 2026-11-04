import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multimeter_viewer/app.dart';
import 'package:multimeter_viewer/devices/fluke/qdda.dart';
import 'package:multimeter_viewer/l10n/app_localizations.dart';
import 'package:multimeter_viewer/meter/model/model.dart';
import 'package:multimeter_viewer/ui/meter_page.dart';
import 'package:multimeter_viewer/ui/widgets/capability_panel.dart';

import 'fakes.dart';

const _capabilities = MeterCapabilities(
  measurements: [
    MeterCapability(
      'MV_AC',
      subFunctions: [
        MeterSubFunction('PEAK_MIN_MAX', MeterSubFunctionKind.secondary),
        MeterSubFunction('MIN_MAX_AVG', MeterSubFunctionKind.mode),
        MeterSubFunction('HOLD', MeterSubFunctionKind.mode, settable: true),
      ],
    ),
    MeterCapability('OHMS', settable: true),
    MeterCapability('V_DC'),
  ],
);

void main() {
  final calls = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    MeterCapabilities capabilities = _capabilities,
    String qdda = sampleQddaMinMax,
  }) async {
    calls.clear();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CapabilityPanel(
            capabilities: capabilities,
            display: parseDisplay(qdda),
            onSet: (id, {subFunction, required active}) =>
                calls.add('$id/$subFunction=$active'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilterChip chip(WidgetTester tester, String label) =>
      tester.widget(find.widgetWithText(FilterChip, label));

  testWidgets('marks what the meter reports as active', (tester) async {
    await pump(tester);
    expect(chip(tester, 'Peak Min/Max').selected, isTrue);
    expect(chip(tester, 'Min Max').selected, isTrue);
    expect(chip(tester, 'Hold').selected, isFalse);
    expect(find.text('mV AC'), findsOneWidget);
  });

  testWidgets('a chip without the flag cannot be switched', (tester) async {
    await pump(tester);
    expect(chip(tester, 'Min Max').onSelected, isNull);
    await tester.tap(find.widgetWithText(FilterChip, 'Min Max'));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('a chip with the flag switches', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Hold'));
    await tester.pump();
    expect(calls, ['MV_AC/HOLD=true']);
  });

  testWidgets('the menu lists all modes, only settable ones work', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('mV AC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('V DC'), warnIfMissed: false);
    await tester.pump();
    expect(calls, isEmpty);

    await tester.tap(find.text('Resistance'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(calls, ['OHMS/null=true']);
  });

  testWidgets('shows active values the device did not declare', (tester) async {
    await pump(tester, capabilities: const MeterCapabilities());
    expect(chip(tester, 'Peak Min/Max').selected, isTrue);
    expect(chip(tester, 'Min Max').selected, isTrue);
    expect(chip(tester, 'Min Max').onSelected, isNull);
    expect(find.text('mV AC'), findsOneWidget);
  });

  testWidgets('NONE is no subfunction', (tester) async {
    await pump(
      tester,
      capabilities: const MeterCapabilities(),
      qdda: sampleQdda,
    );
    expect(find.byType(FilterChip), findsNothing);
  });

  group('live view', () {
    Future<void> connect(WidgetTester tester, FakeLink link) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultimeterViewerApp(
          settingsStore: MemorySettingsStore(),
          initialSettings: germanSettings,
          discovery: FakeDiscovery(link: link),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Verbinden'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(MeterPage), findsOneWidget);
    }

    Future<void> disconnect(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets('a Fluke offers memory and editing properties', (tester) async {
      await connect(tester, FakeLink());
      expect(find.byType(CapabilityPanel), findsOneWidget);
      expect(find.byIcon(Icons.sd_storage_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('hides features the meter does not offer', (tester) async {
      await connect(
        tester,
        FakeLink(meterCapabilities: const MeterCapabilities()),
      );
      expect(find.byIcon(Icons.sd_storage_outlined), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await disconnect(tester);
    });

    testWidgets('properties without write cannot be edited', (tester) async {
      await connect(
        tester,
        FakeLink(
          meterCapabilities: const MeterCapabilities(
            features: [
              MeterCapability(
                MeterFeatures.properties,
                subFunctions: [
                  MeterSubFunction(
                    MeterFeatures.read,
                    MeterSubFunctionKind.action,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('Geräteinfo'), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await disconnect(tester);
    });
  });
}
