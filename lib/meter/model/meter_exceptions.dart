import 'package:equatable/equatable.dart';

/// Error reported for a meter [command]. The UI turns these into localized
/// text; [toString] is a technical English description for logs.
sealed class MeterException extends Equatable implements Exception {
  const MeterException(this.command);

  final String command;
}

/// Why a meter refused a command.
enum MeterCommandError { syntax, execution, noData, other }

/// The meter refused [command].
final class MeterCommandRejected extends MeterException {
  const MeterCommandRejected(super.command, this.reason, this.code);

  final MeterCommandError reason;

  /// The answer as the meter sent it.
  final String code;

  @override
  List<Object?> get props => [command, reason, code];

  @override
  String toString() => '$command: rejected with $code';
}

/// The meter did not answer [command] in time.
final class MeterTimeoutException extends MeterException {
  const MeterTimeoutException(super.command);

  @override
  List<Object?> get props => [command];

  @override
  String toString() => '$command: no response from the meter';
}

/// The meter sent data that does not match its protocol.
class MeterParseException extends Equatable implements Exception {
  const MeterParseException(this.message);

  /// Technical English description.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'MeterParseException: $message';
}
