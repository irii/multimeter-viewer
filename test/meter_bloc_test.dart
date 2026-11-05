import 'package:multimeter_viewer/meter/model/model.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/bloc/meter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:multimeter_viewer/devices/fluke/fluke_capabilities.dart';

import 'fakes.dart';

void main() {
  late FakeLink link;

  MeterBloc build({List<Object> responses = const []}) {
    link = FakeLink(responses: responses);
    return MeterBloc(
      connector: (_) async => link,
      pollInterval: const Duration(milliseconds: 1),
      maxConsecutiveFailures: 3,
    );
  }

  blocTest<MeterBloc, MeterState>(
    'connect identifies the meter and starts polling',
    build: build,
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.status, MeterStatus.connected);
      expect(bloc.state.identity, FakeLink.identity);
      expect(bloc.state.display?.primary?.displayText, '7.312');
      expect(bloc.state.history.unit, 'VAC');
    },
    // Every poll with a new meter timestamp emits; check the start order.
    expect: () => containsAllInOrder(<Object>[
      const MeterState(status: MeterStatus.connecting),
      MeterState(
        status: MeterStatus.connected,
        identity: FakeLink.identity,
        capabilities: flukeCapabilities(FakeLink.identity),
        properties: const MeterProperties(),
      ),
      isA<MeterState>().having((s) => s.display, 'display', isNotNull),
    ]),
  );

  blocTest<MeterBloc, MeterState>(
    'connect reads the properties stored in the meter',
    build: () {
      link = FakeLink(
        properties: const MeterProperties(operator: 'Max Muster'),
      );
      return MeterBloc(connector: (_) async => link);
    },
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) => expect(
      bloc.state.properties,
      const MeterProperties(operator: 'Max Muster'),
    ),
  );

  blocTest<MeterBloc, MeterState>(
    'saving writes only the changed properties and reads them back',
    build: () {
      link = FakeLink(
        properties: const MeterProperties(company: 'ACME', site: 'Hall 3'),
      );
      return MeterBloc(connector: (_) async => link);
    },
    act: (bloc) async {
      bloc.add(const MeterConnectRequested(fakeCandidate));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await bloc.saveProperties(
        const MeterProperties(company: 'ACME', operator: 'Max'),
      );
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(link.written, ['operator=Max', 'site=']);
      expect(
        bloc.state.properties,
        const MeterProperties(company: 'ACME', operator: 'Max'),
      );
    },
  );

  blocTest<MeterBloc, MeterState>(
    'connector error leads to failure',
    build: () => MeterBloc(
      connector: (_) async => throw const MeterTimeoutException('ID'),
    ),
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    expect: () => [
      const MeterState(status: MeterStatus.connecting),
      const MeterState(
        status: MeterStatus.failure,
        failure: MeterFailure(
          MeterFailureKind.connect,
          MeterTimeoutException('ID'),
        ),
      ),
    ],
  );

  blocTest<MeterBloc, MeterState>(
    'repeated poll failures disconnect',
    build: () => build(responses: [const MeterTimeoutException('QDDA')]),
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      expect(bloc.state.status, MeterStatus.failure);
      expect(bloc.state.failure?.kind, MeterFailureKind.connectionLost);
      expect(bloc.state.failure?.cause, const MeterTimeoutException('QDDA'));
      expect(link.closed, isTrue);
    },
  );

  blocTest<MeterBloc, MeterState>(
    'single poll failure only warns',
    build: () =>
        build(responses: [const MeterTimeoutException('QDDA'), sampleQdda]),
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.status, MeterStatus.connected);
      expect(bloc.state.warning, isNull);
    },
  );

  blocTest<MeterBloc, MeterState>(
    'disconnect closes the link',
    build: build,
    act: (bloc) async {
      bloc.add(const MeterConnectRequested(fakeCandidate));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const MeterDisconnectRequested());
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state, const MeterState(disconnectedByUser: true));
      expect(link.closed, isTrue);
    },
  );

  blocTest<MeterBloc, MeterState>(
    'device removal leads to failure',
    build: build,
    act: (bloc) async {
      bloc.add(const MeterConnectRequested(fakeCandidate));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      link.removed.add(null);
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.status, MeterStatus.failure);
      expect(
        bloc.state.failure,
        const MeterFailure(MeterFailureKind.cableRemoved),
      );
    },
  );

  group('setting a capability', () {
    const capabilities = MeterCapabilities(
      measurements: [
        MeterCapability(
          'V_DC',
          settable: true,
          subCapabilities: [
            MeterSubCapability(
              'HOLD',
              MeterControl.toggle,
              source: MeterStateSource.mode,
              settable: true,
            ),
            MeterSubCapability(
              'RECORD',
              MeterControl.toggle,
              source: MeterStateSource.mode,
            ),
          ],
        ),
        MeterCapability('OHMS'),
      ],
    );

    MeterBloc settable() {
      link = FakeLink(meterCapabilities: capabilities);
      return MeterBloc(
        connector: (_) async => link,
        pollInterval: const Duration(hours: 1),
      );
    }

    Future<void> connect(MeterBloc bloc) async {
      bloc.add(const MeterConnectRequested(fakeCandidate));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    blocTest<MeterBloc, MeterState>(
      'reaches the meter when settable',
      build: settable,
      act: (bloc) async {
        await connect(bloc);
        bloc
          ..add(const MeterCapabilitySetRequested('V_DC', active: true))
          ..add(
            const MeterCapabilitySetRequested(
              'V_DC',
              sub: 'HOLD',
              active: false,
            ),
          );
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) => expect(link.set, ['V_DC/null=true', 'V_DC/HOLD=false']),
    );

    blocTest<MeterBloc, MeterState>(
      'is ignored when not settable or unknown',
      build: settable,
      act: (bloc) async {
        await connect(bloc);
        bloc
          ..add(const MeterCapabilitySetRequested('OHMS', active: true))
          ..add(
            const MeterCapabilitySetRequested(
              'V_DC',
              sub: 'RECORD',
              active: true,
            ),
          )
          ..add(const MeterCapabilitySetRequested('NOPE', active: true));
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) => expect(link.set, isEmpty),
    );

    blocTest<MeterBloc, MeterState>(
      'reports a failure as a warning',
      build: () {
        final bloc = settable();
        link.setError = StateError('refused');
        return bloc;
      },
      act: (bloc) async {
        await connect(bloc);
        bloc.add(const MeterCapabilitySetRequested('V_DC', active: true));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.status, MeterStatus.connected);
        expect(bloc.state.warning, isA<StateError>());
      },
    );
  });

  blocTest<MeterBloc, MeterState>(
    'does not read properties the meter does not offer',
    build: () {
      link = FakeLink(meterCapabilities: const MeterCapabilities());
      return MeterBloc(
        connector: (_) async => link,
        pollInterval: const Duration(hours: 1),
      );
    },
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.status, MeterStatus.connected);
      expect(bloc.state.properties, isNull);
    },
  );
}
