import '../bloc/meter_bloc.dart';
import '../fluke/fluke_client.dart';
import '../fluke/meter_discovery.dart';
import '../fluke/qdda.dart';
import '../recording/recording.dart';
import '../recording/recording_csv.dart';
import 'app_localizations.dart';

/// Localized messages for the errors raised by the protocol, USB and file
/// layers. Unknown errors (e.g. libusb messages) are shown as they are.
extension ErrorText on AppLocalizations {
  String error(Object error) => switch (error) {
    FlukeAckException(:final command, ack: '1') => errorAckSyntax(command),
    FlukeAckException(:final command, ack: '2') => errorAckExecution(command),
    FlukeAckException(:final command, ack: '5') => errorAckNoData(command),
    FlukeAckException(:final command, :final ack) => errorAckUnexpected(
      command,
      ack,
    ),
    FlukeTimeoutException(:final command) => errorNoResponse(command),
    FlukeParseException(:final message) => errorInvalidData(message),
    MeterDiscoveryException(error: MeterDiscoveryError.deviceGone) =>
      errorDeviceGone,
    MeterDiscoveryException(error: MeterDiscoveryError.deviceInUse) =>
      errorDeviceInUse,
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
    if (error is FlukeTimeoutException) return hintNoResponse;
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
