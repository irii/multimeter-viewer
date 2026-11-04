import 'package:async/async.dart' show StreamGroup;
import 'package:equatable/equatable.dart';

import '../adapters/adapter.dart';
import 'meter_link.dart';
import 'model/meter_identity.dart';
import 'model/meter_properties.dart';

export '../adapters/adapter.dart'
    show AdapterError, AdapterException, AdapterTransport;

/// A USB cable or Bluetooth adapter found during a scan, with the meter that
/// answered on it.
class MeterCandidate extends Equatable {
  const MeterCandidate({
    required this.id,
    required this.cableName,
    this.transport = AdapterTransport.usb,
    this.identity,
    this.properties,
    this.error,
  });

  /// Stable key of the cable within one discovery instance.
  final String id;

  /// Name of the cable or adapter.
  final String cableName;
  final AdapterTransport transport;

  /// Meter that answered the `ID` query, `null` if none did.
  final MeterIdentity? identity;

  /// Owner texts stored in that meter, if they could be read.
  final MeterProperties? properties;

  /// Why the cable could not be queried, e.g. a [MeterTimeoutException]
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

/// Finds meters and connects to them. Implemented by each kind of device.
abstract interface class MeterDiscovery {
  /// Whether the user must grant devices first ([requestDevice], WebUSB).
  bool get canRequestDevice;

  /// Whether a single available meter should be connected automatically
  /// (Android, where the app is used with one cable at a time).
  bool get autoSelectSingle;

  /// Names of the devices this discovery can find, e.g. for the user.
  List<String> get supportedDevices;

  /// Lists all cables and asks each for its meter identity.
  Future<List<MeterCandidate>> scan();

  /// Shows the browser's device chooser (WebUSB); no-op natively.
  Future<void> requestDevice();

  Future<MeterLink> connect(MeterCandidate candidate);

  /// Fires when a cable is plugged in or removed.
  Stream<void> get onDevicesChanged;

  /// Releases what it holds when the app quits; the discovery must not be
  /// used afterwards.
  void dispose();
}

/// Combines several discoveries into one list, in the order given. A device
/// listed by more than one counts for the one that found a meter on it.
class CompositeMeterDiscovery implements MeterDiscovery {
  CompositeMeterDiscovery(this._parts, {this._onDispose});

  final List<MeterDiscovery> _parts;
  final void Function()? _onDispose;

  /// Which part listed each candidate of the last scan.
  Map<String, MeterDiscovery> _routes = {};

  @override
  List<String> get supportedDevices => [
    for (final part in _parts) ...part.supportedDevices,
  ];

  @override
  bool get canRequestDevice => _parts.any((p) => p.canRequestDevice);

  @override
  bool get autoSelectSingle => _parts.every((p) => p.autoSelectSingle);

  /// A part that fails (e.g. libusb missing) only hides its own devices; the
  /// error is reported when nothing was found at all.
  @override
  Future<List<MeterCandidate>> scan() async {
    Object? firstError;
    StackTrace? firstStack;
    final results = await Future.wait([
      for (final part in _parts)
        part.scan().catchError((Object e, StackTrace s) {
          firstError ??= e;
          firstStack ??= s;
          return <MeterCandidate>[];
        }),
    ]);
    final candidates = <String, MeterCandidate>{};
    final routes = <String, MeterDiscovery>{};
    for (var i = 0; i < _parts.length; i++) {
      for (final candidate in results[i]) {
        final known = candidates[candidate.id];
        if (known == null || (!known.hasMeter && candidate.hasMeter)) {
          candidates[candidate.id] = candidate;
          routes[candidate.id] = _parts[i];
        }
      }
    }
    _routes = routes;
    if (candidates.isEmpty && firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
    return candidates.values.toList();
  }

  @override
  Future<void> requestDevice() async {
    for (final part in _parts) {
      if (part.canRequestDevice) await part.requestDevice();
    }
  }

  @override
  Future<MeterLink> connect(MeterCandidate candidate) async {
    final part = _routes[candidate.id];
    if (part == null) {
      throw const AdapterException(AdapterError.deviceGone);
    }
    return part.connect(candidate);
  }

  @override
  Stream<void> get onDevicesChanged =>
      StreamGroup.merge([for (final p in _parts) p.onDevicesChanged]);

  @override
  void dispose() {
    for (final part in _parts) {
      part.dispose();
    }
    _onDispose?.call();
  }
}
