import 'package:bloc_test/bloc_test.dart';
import 'package:multimeter_viewer/bloc/meter_bloc.dart';
import 'package:multimeter_viewer/fluke/fluke_client.dart';
import 'package:flutter_test/flutter_test.dart';

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
      const MeterState(
        status: MeterStatus.connected,
        identity: FakeLink.identity,
        properties: MeterProperties(),
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
      connector: (_) async => throw const FlukeTimeoutException('ID'),
    ),
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    expect: () => [
      const MeterState(status: MeterStatus.connecting),
      const MeterState(
        status: MeterStatus.failure,
        failure: MeterFailure(
          MeterFailureKind.connect,
          FlukeTimeoutException('ID'),
        ),
      ),
    ],
  );

  blocTest<MeterBloc, MeterState>(
    'repeated poll failures disconnect',
    build: () => build(responses: [const FlukeTimeoutException('QDDA')]),
    act: (bloc) => bloc.add(const MeterConnectRequested(fakeCandidate)),
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      expect(bloc.state.status, MeterStatus.failure);
      expect(bloc.state.failure?.kind, MeterFailureKind.connectionLost);
      expect(bloc.state.failure?.cause, const FlukeTimeoutException('QDDA'));
      expect(link.closed, isTrue);
    },
  );

  blocTest<MeterBloc, MeterState>(
    'single poll failure only warns',
    build: () =>
        build(responses: [const FlukeTimeoutException('QDDA'), sampleQdda]),
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
}
