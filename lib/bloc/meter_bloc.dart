import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../fluke/fluke_client.dart';
import '../fluke/meter_discovery.dart';
import '../fluke/qdda.dart';
import 'history.dart';

export 'history.dart';

part 'meter_event.dart';
part 'meter_state.dart';

/// Opens a connection to the meter on [candidate].
typedef MeterConnector = Future<MeterLink> Function(MeterCandidate candidate);

class MeterBloc extends Bloc<MeterEvent, MeterState> {
  MeterBloc({
    required this.connector,
    this.pollInterval = const Duration(milliseconds: 200),
    this.maxConsecutiveFailures = 5,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const MeterState()) {
    on<MeterConnectRequested>(_onConnect, transformer: droppable());
    on<MeterDisconnectRequested>(_onDisconnect);
    on<_MeterPolled>(_onPolled);
    on<_MeterPollFailed>(_onPollFailed);
    on<_MeterDeviceRemoved>(_onDeviceRemoved);
  }

  final MeterConnector connector;
  final Duration pollInterval;
  final int maxConsecutiveFailures;
  final DateTime Function() _clock;

  MeterLink? _link;

  /// The open connection, `null` while disconnected.
  MeterLink? get link => _link;
  StreamSubscription<void>? _removedSub;
  int _consecutiveFailures = 0;

  Future<void> _onConnect(
    MeterConnectRequested event,
    Emitter<MeterState> emit,
  ) async {
    if (_link != null) return;
    emit(const MeterState(status: MeterStatus.connecting));

    MeterLink? link;
    try {
      link = await connector(event.candidate);
      final identity = await link.identify();
      _link = link;
      _consecutiveFailures = 0;
      _removedSub = link.onRemoved.listen(
        (_) => add(const _MeterDeviceRemoved()),
      );
      emit(MeterState(status: MeterStatus.connected, identity: identity));
      unawaited(_pollLoop(link));
    } catch (e) {
      await _closeQuietly(link);
      emit(
        MeterState(
          status: MeterStatus.failure,
          failure: MeterFailure(MeterFailureKind.connect, e),
        ),
      );
    }
  }

  Future<void> _pollLoop(MeterLink link) async {
    bool active() => identical(_link, link) && !isClosed;
    while (active()) {
      try {
        final display = await link.queryDisplay();
        if (!active()) break;
        add(_MeterPolled(display));
      } catch (e) {
        if (!active()) break;
        add(_MeterPollFailed(e));
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  void _onPolled(_MeterPolled event, Emitter<MeterState> emit) {
    if (_link == null) return;
    _consecutiveFailures = 0;
    final receivedAt = _clock();
    emit(
      state.copyWith(
        display: event.display,
        receivedAt: receivedAt,
        history: state.history.append(
          event.display.primary,
          receivedAt: receivedAt,
        ),
        warning: () => null,
      ),
    );
  }

  Future<void> _onPollFailed(
    _MeterPollFailed event,
    Emitter<MeterState> emit,
  ) async {
    if (_link == null) return;
    _consecutiveFailures++;
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      await _shutdown();
      emit(
        MeterState(
          status: MeterStatus.failure,
          failure: MeterFailure(MeterFailureKind.connectionLost, event.error),
        ),
      );
    } else {
      emit(state.copyWith(warning: () => event.error));
    }
  }

  Future<void> _onDisconnect(
    MeterDisconnectRequested event,
    Emitter<MeterState> emit,
  ) async {
    await _shutdown();
    emit(const MeterState(disconnectedByUser: true));
  }

  Future<void> _onDeviceRemoved(
    _MeterDeviceRemoved event,
    Emitter<MeterState> emit,
  ) async {
    if (_link == null) return;
    await _shutdown();
    emit(
      const MeterState(
        status: MeterStatus.failure,
        failure: MeterFailure(MeterFailureKind.cableRemoved),
      ),
    );
  }

  Future<void> _shutdown() async {
    final link = _link;
    _link = null;
    unawaited(_removedSub?.cancel());
    _removedSub = null;
    await _closeQuietly(link);
  }

  static Future<void> _closeQuietly(MeterLink? link) async {
    try {
      await link?.close();
    } catch (_) {
      // Closing a vanished device can fail; nothing left to clean up.
    }
  }

  @override
  Future<void> close() async {
    await _shutdown();
    return super.close();
  }
}
