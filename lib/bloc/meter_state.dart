part of 'meter_bloc.dart';

enum MeterStatus { disconnected, connecting, connected, failure }

enum MeterFailureKind {
  /// Opening the cable or identifying the meter failed.
  connect,

  /// Too many polls failed in a row.
  connectionLost,

  /// The USB cable was unplugged.
  cableRemoved,
}

/// Why the connection failed or was dropped; the UI localizes it.
final class MeterFailure extends Equatable {
  const MeterFailure(this.kind, [this.cause]);

  final MeterFailureKind kind;

  /// Underlying error, if any.
  final Object? cause;

  @override
  List<Object?> get props => [kind, cause];
}

final class MeterState extends Equatable {
  const MeterState({
    this.status = MeterStatus.disconnected,
    this.identity,
    this.display,
    this.receivedAt,
    this.history = const SampleHistory(),
    this.failure,
    this.warning,
    this.disconnectedByUser = false,
  });

  final MeterStatus status;
  final MeterIdentity? identity;
  final QddaResponse? display;

  /// System time [display] was received. Not part of equality, so an
  /// unchanged display (e.g. HOLD) does not cause a rebuild.
  final DateTime? receivedAt;
  final SampleHistory history;

  /// Why the connection failed or was dropped.
  final MeterFailure? failure;

  /// Transient problem while connected (e.g. one missed poll).
  final Object? warning;

  /// The user ended the last connection (so it is not re-opened
  /// automatically).
  final bool disconnectedByUser;

  bool get isConnected => status == MeterStatus.connected;

  MeterState copyWith({
    MeterStatus? status,
    MeterIdentity? identity,
    QddaResponse? display,
    DateTime? receivedAt,
    SampleHistory? history,
    MeterFailure? Function()? failure,
    Object? Function()? warning,
  }) => MeterState(
    status: status ?? this.status,
    identity: identity ?? this.identity,
    display: display ?? this.display,
    receivedAt: receivedAt ?? this.receivedAt,
    history: history ?? this.history,
    failure: failure != null ? failure() : this.failure,
    warning: warning != null ? warning() : this.warning,
  );

  @override
  List<Object?> get props => [
    status,
    identity,
    display,
    history,
    failure,
    warning,
    disconnectedByUser,
  ];
}
