import '../../adapters/serial_channel.dart';
import '../../meter/meter_link.dart';
import '../../meter/meter_protocol.dart';
import '../../meter/model/meter_properties.dart';
import 'fluke_client.dart';

/// [MeterProtocol] of the Fluke 287 and 289.
class FlukeProtocol implements MeterProtocol {
  const FlukeProtocol();

  @override
  Future<MeterProbe> probe(
    SerialChannel channel, {
    required Duration timeout,
  }) async {
    final client = FlukeClient(channel);
    final identity = await client.identify(timeout: timeout);
    MeterProperties? properties;
    try {
      properties = await client.readProperties();
    } catch (_) {
      // Only shown as extra information in the device list.
    }
    return MeterProbe(identity: identity, properties: properties);
  }

  @override
  MeterLink attach(SerialChannel channel) => FlukeClient(channel);
}
