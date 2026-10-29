part of 'meter_bloc.dart';

sealed class MeterEvent extends Equatable {
  const MeterEvent();

  @override
  List<Object?> get props => [];
}

/// Opens the USB cable of [candidate] and starts polling the meter.
final class MeterConnectRequested extends MeterEvent {
  const MeterConnectRequested(this.candidate);

  final MeterCandidate candidate;

  @override
  List<Object?> get props => [candidate];
}

/// Stops polling and closes the USB cable.
final class MeterDisconnectRequested extends MeterEvent {
  const MeterDisconnectRequested();
}

final class _MeterPolled extends MeterEvent {
  const _MeterPolled(this.display);

  final QddaResponse display;

  @override
  List<Object?> get props => [display];
}

final class _MeterPollFailed extends MeterEvent {
  const _MeterPollFailed(this.error);

  final Object error;

  @override
  List<Object?> get props => [error];
}

final class _MeterDeviceRemoved extends MeterEvent {
  const _MeterDeviceRemoved();
}

final class _MeterPropertiesRead extends MeterEvent {
  const _MeterPropertiesRead(this.properties);

  final MeterProperties? properties;

  @override
  List<Object?> get props => [properties];
}
