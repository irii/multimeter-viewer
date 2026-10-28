import 'package:flutter_bloc/flutter_bloc.dart';

/// Clock used for the time axis of the live chart.
enum TimeBase {
  /// Timestamps reported by the meter.
  meter,

  /// System time the readings were received.
  system,
}

/// Selected [TimeBase] of the live view; survives reconnects.
class TimeBaseCubit extends Cubit<TimeBase> {
  TimeBaseCubit() : super(TimeBase.meter);

  void select(TimeBase timeBase) => emit(timeBase);
}
