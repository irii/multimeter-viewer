import 'meter_memory.dart';
import 'model/meter_display.dart';
import 'model/meter_identity.dart';
import 'model/meter_properties.dart';

/// What the UI layer needs from a connected meter.
abstract interface class MeterLink {
  Future<MeterIdentity> identify();

  Future<MeterDisplay> queryDisplay();

  /// Company, operator, site and contact stored in the meter.
  Future<MeterProperties> readProperties();

  /// Stores [value] as the property [name] (one of [MeterProperties.names]);
  /// an empty [value] clears it.
  Future<void> writeProperty(String name, String value);

  Stream<void> get onRemoved;

  /// Access to recordings and measurements saved in the meter.
  MeterMemory get memory;

  Future<void> close();
}
