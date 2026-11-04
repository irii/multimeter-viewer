import 'package:equatable/equatable.dart';

import 'serial_channel.dart';

/// How a device is reached.
enum AdapterTransport { usb, bluetooth }

enum AdapterError {
  /// The device vanished since it was last listed.
  deviceGone,

  /// The device is already open.
  deviceInUse,
}

class AdapterException extends Equatable implements Exception {
  const AdapterException(this.error);

  final AdapterError error;

  @override
  List<Object?> get props => [error];

  @override
  String toString() => 'AdapterException: ${error.name}';
}

/// A device an [Adapter] can open.
class AdapterDevice extends Equatable {
  const AdapterDevice({
    required this.id,
    required this.name,
    this.inUse = false,
  });

  /// Stable key of the device within one adapter instance.
  final String id;
  final String name;

  /// Whether a channel to this device is open.
  final bool inUse;

  @override
  List<Object?> get props => [id, name, inUse];
}

/// Finds devices over one transport and opens them as byte channels. Knows
/// nothing about what speaks on the other end: it only offers devices that
/// match a filter [F] attached to it, and several users can share one adapter.
abstract interface class Adapter<F> {
  AdapterTransport get transport;

  /// Whether the user must grant devices first ([requestDevice], WebUSB).
  bool get canRequestDevice;

  /// Whether a single available device should be connected automatically
  /// (Android, where the app is used with one device at a time).
  bool get autoSelectSingle;

  /// How long a device's last probe stays valid; `null`: probe on every scan.
  Duration? get reprobeAfter;

  /// Adds [filter] to the devices this adapter offers.
  void attachFilter(F filter);

  /// Removes a [filter] added with [attachFilter].
  void detachFilter(F filter);

  /// The devices matching the attached filters, or only those matching [only].
  Future<List<AdapterDevice>> listDevices({List<F>? only});

  /// Shows the browser's device chooser (WebUSB); no-op natively.
  Future<void> requestDevice();

  /// Opens the device [deviceId] from [listDevices]. It counts as in use
  /// until the channel is closed.
  ///
  /// Throws an [AdapterException] if it is gone or already open.
  Future<SerialChannel> open(String deviceId);

  /// Runs [action] after all previously queued actions, so users sharing this
  /// adapter never talk to a device at the same time.
  Future<T> exclusive<T>(Future<T> Function() action);

  /// Fires when a device matching an attached filter is plugged in or removed.
  Stream<void> get onDevicesChanged;

  /// Releases the transport when the app quits; the adapter must not be used
  /// afterwards.
  void dispose();
}

/// Implements [Adapter.exclusive].
mixin AdapterQueue {
  Future<void> _queue = Future.value();

  Future<T> exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
