import '../adapters/serial_channel.dart';
import 'meter_link.dart';
import 'model/meter_identity.dart';
import 'model/meter_properties.dart';

/// What a [MeterProtocol] learned about the device on a channel.
class MeterProbe {
  const MeterProbe({required this.identity, this.properties});

  final MeterIdentity identity;

  /// Owner texts stored in the meter, if they could be read.
  final MeterProperties? properties;
}

/// Speaks to one kind of meter over a byte channel. Adding a new kind of
/// device means implementing this and registering it with its adapters.
abstract interface class MeterProtocol {
  /// Asks the device on [channel] who it is, within [timeout]. Throws if no
  /// meter of this kind answers. Does not close the channel.
  Future<MeterProbe> probe(SerialChannel channel, {required Duration timeout});

  /// The connection to the meter on [channel]; closing it closes the channel.
  MeterLink attach(SerialChannel channel);
}
