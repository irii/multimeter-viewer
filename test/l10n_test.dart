import 'dart:convert';
import 'dart:io';

import 'package:multimeter_viewer/app.dart';
import 'package:multimeter_viewer/bloc/meter_bloc.dart';
import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/l10n/l10n.dart';
import 'package:multimeter_viewer/recording/recording.dart';
import 'package:multimeter_viewer/recording/recording_csv.dart';
import 'package:multimeter_viewer/settings/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'recording_csv_test.dart' show sampleRecording;

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test('both ARB files define the same keys', () {
    Set<String> keys(String lang) => (jsonDecode(
      File('lib/l10n/app_$lang.arb').readAsStringSync(),
    ) as Map<String, dynamic>).keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys('de'), keys('en'));
  });

  test('system language: German or English, else English', () {
    const supported = [Locale('de'), Locale('en')];
    expect(
      resolveLocale(const [Locale('de', 'AT')], supported),
      const Locale('de'),
    );
    expect(
      resolveLocale(const [Locale('fr'), Locale('en', 'GB')], supported),
      const Locale('en'),
    );
    expect(resolveLocale(const [Locale('fr')], supported), const Locale('en'));
    expect(resolveLocale(null, supported), const Locale('en'));
  });

  test('errors are localized', () {
    expect(
      en.error(const FlukeAckException('QDDA', '1')),
      'QDDA: syntax error',
    );
    expect(
      de.error(const FlukeAckException('QDDA', '1')),
      'QDDA: Syntaxfehler',
    );
    expect(
      de.error(const FlukeTimeoutException('ID')),
      'ID: Keine Antwort vom Messgerät',
    );
    expect(
      en.meterFailure(const MeterFailure(MeterFailureKind.cableRemoved)),
      'The USB cable was disconnected.',
    );
    expect(
      en.error(
        const RecordingFormatException(
          RecordingFormatError.missingColumn,
          detail: 'value',
        ),
      ),
      'Invalid recording file: column “value” is missing',
    );
    expect(
      en.connectionHint(const FlukeTimeoutException('ID')),
      en.hintNoResponse,
    );
    // Unknown errors (e.g. from libusb) are shown as they are.
    expect(en.error(StateError('x')), 'Bad state: x');
  });

  test('labels and plurals', () {
    expect(en.primaryFunction('OHMS'), 'Resistance');
    expect(de.primaryFunction('OHMS'), 'Widerstand');
    expect(de.primaryFunction('MV_AC'), 'mV AC');
    expect(en.sampleCount(1), '1 reading');
    expect(de.sampleCount(3), '3 Messwerte');
    expect(
      en.stopReason(RecordingStopReason.disconnected),
      'Meter disconnected',
    );
  });

  test('CSV stores stop reasons language-neutral', () {
    final csv = recordingToCsv(sampleRecording());
    expect(csv, contains('# Stopped: stopped'));
    expect(recordingFromCsv(csv).stopReason, RecordingStopReason.stopped);
  });

  testWidgets('switches language and theme in the settings dialog', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      MultimeterViewerApp(
        discovery: FakeDiscovery(),
        settingsStore: store,
        initialSettings: const AppSettings(language: AppLanguage.en),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available meters'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    expect(find.text('Verfügbare Messgeräte'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Verfügbare Messgeräte'))).brightness,
      Brightness.dark,
    );
    expect(
      store.settings,
      const AppSettings(language: AppLanguage.de, themeMode: ThemeMode.dark),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
