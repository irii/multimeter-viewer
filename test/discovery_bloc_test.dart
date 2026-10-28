import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/bloc/discovery_bloc.dart';
import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:multimeter_viewer/fluke/meter_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  const cableOnly = MeterCandidate(
    id: '403:6001:B2',
    cableName: 'FT232R (B2)',
    error: FlukeTimeoutException('ID'),
  );

  blocTest<DiscoveryBloc, DiscoveryState>(
    'scan splits meters and cables without meter',
    build: () => DiscoveryBloc(
      discovery: FakeDiscovery(candidates: const [fakeCandidate, cableOnly]),
    ),
    act: (bloc) => bloc.add(const DiscoveryScanRequested()),
    expect: () => [
      const DiscoveryState(scanning: true),
      const DiscoveryState(
        scanned: true,
        candidates: [fakeCandidate, cableOnly],
      ),
    ],
    verify: (bloc) {
      expect(bloc.state.meters, [fakeCandidate]);
      expect(bloc.state.cablesWithoutMeter, [cableOnly]);
    },
  );

  blocTest<DiscoveryBloc, DiscoveryState>(
    'scan error is reported',
    build: () =>
        DiscoveryBloc(discovery: FakeDiscovery()..scanError = 'kein libusb'),
    act: (bloc) => bloc.add(const DiscoveryScanRequested()),
    skip: 1,
    expect: () => [const DiscoveryState(scanned: true, error: 'kein libusb')],
  );

  late FakeDiscovery discovery;
  blocTest<DiscoveryBloc, DiscoveryState>(
    'device change triggers a rescan',
    build: () {
      discovery = FakeDiscovery();
      return DiscoveryBloc(discovery: discovery);
    },
    act: (bloc) => discovery.changes.add(null),
    wait: const Duration(milliseconds: 10),
    verify: (_) => expect(discovery.scans, 1),
  );

  late FakeDiscovery autoDiscovery;
  blocTest<DiscoveryBloc, DiscoveryState>(
    'rescans automatically without showing progress again',
    build: () {
      autoDiscovery = FakeDiscovery();
      return DiscoveryBloc(
        discovery: autoDiscovery,
        autoScanInterval: const Duration(milliseconds: 10),
      );
    },
    act: (bloc) => bloc.add(const DiscoveryScanRequested()),
    wait: const Duration(milliseconds: 55),
    // Only the first (manual) scan shows progress; identical automatic
    // results don't emit.
    expect: () => [
      const DiscoveryState(scanning: true),
      const DiscoveryState(scanned: true, candidates: [fakeCandidate]),
    ],
    verify: (_) => expect(autoDiscovery.scans, greaterThanOrEqualTo(3)),
  );

  blocTest<DiscoveryBloc, DiscoveryState>(
    'automatic scan picks up a newly found meter',
    build: () {
      autoDiscovery = FakeDiscovery(candidates: const []);
      return DiscoveryBloc(
        discovery: autoDiscovery,
        autoScanInterval: const Duration(milliseconds: 10),
      );
    },
    act: (bloc) async {
      bloc.add(const DiscoveryScanRequested());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      autoDiscovery.candidates = const [fakeCandidate];
    },
    wait: const Duration(milliseconds: 40),
    verify: (bloc) => expect(bloc.state.meters, [fakeCandidate]),
  );
}
