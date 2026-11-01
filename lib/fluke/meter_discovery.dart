import 'package:async/async.dart' show StreamGroup;
import 'package:equatable/equatable.dart';

import 'fluke_client.dart';
import 'qdda.dart';

/// How the app reaches a meter.
enum MeterTransport {
  /// IR-USB cable.
  usb,

  /// Bluetooth IR adapter (`firmware/28x-ir-dongle`).
  bluetooth,
}

/// A USB cable or Bluetooth adapter found during a scan, with the meter that
/// answered on it.
class MeterCandidate extends Equatable {
  const MeterCandidate({
    required this.id,
    required this.cableName,
    this.transport = MeterTransport.usb,
    this.identity,
    this.properties,
    this.error,
  });

  /// Stable key of the cable within one discovery instance.
  final String id;

  /// Name of the cable or adapter.
  final String cableName;
  final MeterTransport transport;

  /// Meter that answered the `ID` query, `null` if none did.
  final MeterIdentity? identity;

  /// Owner texts stored in that meter, if they could be read.
  final MeterProperties? properties;

  /// Why the cable could not be queried, e.g. a [FlukeTimeoutException]
  /// when no meter answers.
  final Object? error;

  bool get hasMeter => identity != null;

  @override
  List<Object?> get props => [
    id,
    cableName,
    transport,
    identity,
    properties,
    error,
  ];
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

  /// Releases the USB backend when the app quits; the discovery must not be
  /// used afterwards.
  void dispose();
}

/// Combines the discoveries of several transports into one list; USB
/// first.
class CompositeMeterDiscovery implements MeterDiscovery {
  CompositeMeterDiscovery(this._parts);

  final Map<MeterTransport, MeterDiscovery> _parts;

  @override
  bool get canRequestDevice => _parts.values.any((p) => p.canRequestDevice);

  @override
  bool get autoSelectSingle => _parts.values.every((p) => p.autoSelectSingle);

  /// A transport that fails (e.g. libusb missing) only hides its own
  /// devices; the error is reported when nothing was found at all.
  @override
  Future<List<MeterCandidate>> scan() async {
    Object? firstError;
    StackTrace? firstStack;
    final results = await Future.wait([
      for (final part in _parts.values)
        part.scan().catchError((Object e, StackTrace s) {
          firstError ??= e;
          firstStack ??= s;
          return <MeterCandidate>[];
        }),
    ]);
    final candidates = [for (final r in results) ...r];
    if (candidates.isEmpty && firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
    return candidates;
  }

  @override
  Future<void> requestDevice() async {
    for (final part in _parts.values) {
      if (part.canRequestDevice) await part.requestDevice();
    }
  }

  @override
  Future<MeterLink> connect(MeterCandidate candidate) {
    final part = _parts[candidate.transport];
    if (part == null) {
      throw const MeterDiscoveryException(MeterDiscoveryError.deviceGone);
    }
    return part.connect(candidate);
  }

  @override
  Stream<void> get onDevicesChanged =>
      StreamGroup.merge([for (final p in _parts.values) p.onDevicesChanged]);

  @override
  void dispose() {
    for (final part in _parts.values) {
      part.dispose();
    }
  }
}
