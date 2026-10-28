import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../fluke/meter_discovery.dart';

sealed class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();

  @override
  List<Object?> get props => [];
}

/// Rescans all cables. A [silent] scan (automatic) does not show progress.
final class DiscoveryScanRequested extends DiscoveryEvent {
  const DiscoveryScanRequested({this.silent = false});

  final bool silent;

  @override
  List<Object?> get props => [silent];
}

/// Lets the user grant another device (WebUSB chooser), then rescans.
final class DiscoveryDeviceRequested extends DiscoveryEvent {
  const DiscoveryDeviceRequested();
}

final class DiscoveryState extends Equatable {
  const DiscoveryState({
    this.scanning = false,
    this.scanned = false,
    this.candidates = const [],
    this.error,
  });

  final bool scanning;

  /// Whether at least one scan has completed.
  final bool scanned;
  final List<MeterCandidate> candidates;
  final Object? error;

  List<MeterCandidate> get meters => [
    for (final c in candidates)
      if (c.hasMeter) c,
  ];

  List<MeterCandidate> get cablesWithoutMeter => [
    for (final c in candidates)
      if (!c.hasMeter) c,
  ];

  @override
  List<Object?> get props => [scanning, scanned, candidates, error];
}

/// Lists the meters reachable over the connected USB cables. Lives only
/// while the connect page is shown, so it never probes a cable in use.
class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  DiscoveryBloc({
    required MeterDiscovery discovery,
    this.autoScanInterval = const Duration(seconds: 3),
  }) : _discovery = discovery,
       super(const DiscoveryState()) {
    on<DiscoveryEvent>(
      (event, emit) => switch (event) {
        DiscoveryScanRequested(:final silent) => _scan(emit, silent: silent),
        DiscoveryDeviceRequested() => _request(emit),
      },
      transformer: droppable(),
    );
    _changesSub = discovery.onDevicesChanged.listen(
      (_) => add(const DiscoveryScanRequested(silent: true)),
    );
    _autoScan = Timer.periodic(
      autoScanInterval,
      (_) => add(const DiscoveryScanRequested(silent: true)),
    );
  }

  final MeterDiscovery _discovery;

  /// How often the cables are rescanned in the background.
  final Duration autoScanInterval;
  late final StreamSubscription<void> _changesSub;
  late final Timer _autoScan;

  bool _firstMeterScanTaken = false;

  /// `true` only on the first call: lets the page treat the result of its
  /// first completed scan differently from meters that appear later.
  bool takeFirstMeterScan() {
    final first = !_firstMeterScanTaken;
    _firstMeterScanTaken = true;
    return first;
  }

  /// Whether a single available meter should be connected automatically.
  bool get autoSelectSingle {
    try {
      return _discovery.autoSelectSingle;
    } catch (_) {
      return false;
    }
  }

  bool get canRequestDevice {
    try {
      return _discovery.canRequestDevice;
    } catch (_) {
      return false;
    }
  }

  Future<void> _scan(
    Emitter<DiscoveryState> emit, {
    bool silent = false,
  }) async {
    if (!silent || !state.scanned) {
      emit(
        DiscoveryState(
          scanning: true,
          scanned: state.scanned,
          candidates: state.candidates,
        ),
      );
    }
    try {
      final candidates = await _discovery.scan();
      emit(DiscoveryState(scanned: true, candidates: candidates));
    } catch (e) {
      emit(DiscoveryState(scanned: true, error: e));
    }
  }

  Future<void> _request(Emitter<DiscoveryState> emit) async {
    try {
      await _discovery.requestDevice();
    } catch (_) {
      // Chooser cancelled; just rescan what we have.
    }
    await _scan(emit);
  }

  @override
  Future<void> close() {
    _autoScan.cancel();
    _changesSub.cancel();
    return super.close();
  }
}
