import '../bloc/meter_bloc.dart';
import '../meter/meter_discovery.dart';
import '../meter/model/model.dart';
import '../recording/recording.dart';
import '../recording/recording_csv.dart';
import 'app_localizations.dart';

/// Localized messages for the errors raised by the protocol, USB and file
/// layers. Unknown errors (e.g. libusb messages) are shown as they are.
extension ErrorText on AppLocalizations {
  String error(Object error) => switch (error) {
    MeterCommandRejected(:final command, reason: MeterCommandError.syntax) =>
      errorAckSyntax(command),
    MeterCommandRejected(:final command, reason: MeterCommandError.execution) =>
      errorAckExecution(command),
    MeterCommandRejected(:final command, reason: MeterCommandError.noData) =>
      errorAckNoData(command),
    MeterCommandRejected(:final command, :final code) => errorAckUnexpected(
      command,
      code,
    ),
    MeterTimeoutException(:final command) => errorNoResponse(command),
    MeterParseException(:final message) => errorInvalidData(message),
    AdapterException(error: AdapterError.deviceGone) => errorDeviceGone,
    AdapterException(error: AdapterError.deviceInUse) => errorDeviceInUse,
    RecordingFormatException(
      error: RecordingFormatError.missingColumn,
      :final detail,
    ) =>
      errorRecordingMissingColumn(detail ?? ''),
    RecordingFormatException(error: RecordingFormatError.noTable) =>
      errorRecordingNoTable,
    RecordingFormatException(
      error: RecordingFormatError.invalidTime,
      :final line,
    ) =>
      errorRecordingInvalidTime(line ?? 0),
    _ => '$error',
  };

  String meterFailure(MeterFailure failure) => switch (failure.kind) {
    MeterFailureKind.connect => error(failure.cause ?? connectionFailed),
    MeterFailureKind.connectionLost => errorConnectionLost(
      error(failure.cause ?? ''),
    ),
    MeterFailureKind.cableRemoved => errorCableRemoved,
  };

  String stopReason(RecordingStopReason reason) => switch (reason) {
    RecordingStopReason.stopped => stopReasonStopped,
    RecordingStopReason.disconnected => stopReasonDisconnected,
  };

  /// What the user can do about [error], or `null` if there is no advice.
  String? connectionHint(Object? error) {
    if (error == null) return null;
    if (error is MeterTimeoutException) return hintNoResponse;
    final text = '$error';
    if (text.contains('libusb-1.0 shared library')) return hintLibusbMissing;
    if (text.contains('LIBUSB_ERROR_BUSY') ||
        text.contains('LIBUSB_ERROR_ACCESS')) {
      return hintDriverBusy;
    }
    if (text.contains('WebUSB is not supported')) return hintNoWebUsb;
    return null;
  }
}
