import 'package:equatable/equatable.dart';

import 'fluke_client.dart';
import 'qdda.dart';

/// A USB cable found during a scan, with the meter that answered on it.
class MeterCandidate extends Equatable {
  const MeterCandidate({
    required this.id,
    required this.cableName,
    this.identity,
    this.error,
  });

  /// Stable key of the cable within one discovery instance.
  final String id;
  final String cableName;

  /// Meter that answered the `ID` query, `null` if none did.
  final MeterIdentity? identity;

  /// Why the cable could not be queried, e.g. a [FlukeTimeoutException]
  /// when no meter answers.
  final Object? error;

  bool get hasMeter => identity != null;

  @override
  List<Object?> get props => [id, cableName, identity, error];
}

enum MeterDiscoveryError {
  /// The cable vanished since the last scan.
  deviceGone,

  /// A connection to this meter is already open.
  deviceInUse,
}

class MeterDiscoveryException extends Equatable implements Exception {
  const MeterDiscoveryException(this.error);

  final MeterDiscoveryError error;

  @override
  List<Object?> get props => [error];

  @override
  String toString() => 'MeterDiscoveryException: ${error.name}';
}

/// Finds meters and connects to them.
abstract interface class MeterDiscovery {
  /// Whether the user must grant devices first ([requestDevice], WebUSB).
  bool get canRequestDevice;

  /// Whether a single available meter should be connected automatically
  /// (Android, where the app is used with one cable at a time).
  bool get autoSelectSingle;

  /// Lists all cables and asks each for its meter identity.
  Future<List<MeterCandidate>> scan();

  /// Shows the browser's device chooser (WebUSB); no-op natively.
  Future<void> requestDevice();

  Future<MeterLink> connect(MeterCandidate candidate);

  /// Fires when a cable is plugged in or removed.
  Stream<void> get onDevicesChanged;
}
