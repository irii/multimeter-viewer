import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/meter_bloc.dart';
import '../fluke/qdda.dart';
import 'recording.dart';

export 'recording.dart';

part 'recording_event.dart';
part 'recording_state.dart';

/// Records the meter's displays for a fixed duration. Fed by the
/// [MeterBloc]'s state stream.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc({
    required Stream<MeterState> meterStates,
    DateTime Function()? clock,
    this.tickInterval = const Duration(milliseconds: 500),
  }) : _clock = clock ?? DateTime.now,
       super(const RecordingState()) {
    on<RecordingStartRequested>(_onStart);
    on<RecordingStopRequested>(_onStop);
    on<RecordingDiscarded>(_onDiscard);
    on<_RecordingMeterUpdated>(_onMeterUpdated);
    on<_RecordingTicked>(_onTicked);
    _meterSub = meterStates.listen((s) => add(_RecordingMeterUpdated(s)));
  }

  final DateTime Function() _clock;
  final Duration tickInterval;
  late final StreamSubscription<MeterState> _meterSub;
  Timer? _ticker;
  MeterIdentity? _identity;
  double? _lastTimestamp;

  double? _meterStart;
  List<RecordingSample> _samples = [];

  void _onStart(RecordingStartRequested event, Emitter<RecordingState> emit) {
    if (state.status == RecordingStatus.recording) return;
    _samples = [];
    _lastTimestamp = null;
    _meterStart = null;
    _ticker?.cancel();
    _ticker = Timer.periodic(
      tickInterval,
      (_) => add(const _RecordingTicked()),
    );
    emit(
      RecordingState(
        status: RecordingStatus.recording,
        info: event.info,
        identity: _identity,
        startedAt: _clock(),
        samples: List.unmodifiable(_samples),
      ),
    );
  }

  void _onMeterUpdated(
    _RecordingMeterUpdated event,
    Emitter<RecordingState> emit,
  ) {
    final meter = event.meterState;
    if (meter.identity != null) _identity = meter.identity;
    if (state.status != RecordingStatus.recording) return;

    if (!meter.isConnected) {
      _finish(emit, RecordingStopReason.disconnected);
      return;
    }

    final display = meter.display;
    final primary = display?.primary;
    if (display == null || primary == null) return;
    // HOLD freezes the meter timestamp; only record new readings.
    if (primary.timestamp == _lastTimestamp) return;
    _lastTimestamp = primary.timestamp;

    // The recording's time base is the meter clock.
    final meterStart = _meterStart ??= primary.timestamp;
    final meterElapsed = Duration(
      microseconds: ((primary.timestamp - meterStart) * 1e6).round(),
    );
    if (meterElapsed > state.info!.duration) {
      _finish(emit, null);
      return;
    }
    _samples.add(
      RecordingSample.fromDisplay(
        display,
        meterElapsed,
        systemTime: meter.receivedAt ?? _clock(),
      ),
    );
    emit(
      state.copyWith(
        identity: _identity,
        meterStartedAt: meterTimeToDateTime(meterStart),
        elapsed: _elapsed(),
        samples: List.unmodifiable(_samples),
      ),
    );
  }

  void _onTicked(_RecordingTicked event, Emitter<RecordingState> emit) {
    if (state.status != RecordingStatus.recording) return;
    final elapsed = _elapsed();
    if (elapsed >= state.info!.duration) {
      _finish(emit, null);
    } else {
      emit(state.copyWith(elapsed: elapsed));
    }
  }

  void _onStop(RecordingStopRequested event, Emitter<RecordingState> emit) {
    if (state.status != RecordingStatus.recording) return;
    _finish(emit, RecordingStopReason.stopped);
  }

  void _onDiscard(RecordingDiscarded event, Emitter<RecordingState> emit) {
    _ticker?.cancel();
    _samples = [];
    emit(const RecordingState());
  }

  Duration _elapsed() => _clock().difference(state.startedAt!);

  void _finish(Emitter<RecordingState> emit, RecordingStopReason? stopReason) {
    _ticker?.cancel();
    _ticker = null;
    final elapsed = _elapsed();
    final info = state.info!;
    emit(
      state.copyWith(
        status: RecordingStatus.finished,
        elapsed: elapsed > info.duration ? info.duration : elapsed,
        samples: List.unmodifiable(_samples),
        stopReason: () => stopReason,
      ),
    );
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _meterSub.cancel();
    return super.close();
  }
}
