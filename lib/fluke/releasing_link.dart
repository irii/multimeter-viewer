import 'fluke_client.dart';
import 'qdda.dart';

/// Marks the cable or adapter as free again when the connection is closed.
class ReleasingLink implements MeterLink {
  ReleasingLink(this._inner, this._release);

  final MeterLink _inner;
  final void Function() _release;

  @override
  Future<MeterIdentity> identify() => _inner.identify();

  @override
  Future<QddaResponse> queryDisplay() => _inner.queryDisplay();

  @override
  Future<MeterProperties> readProperties() => _inner.readProperties();

  @override
  Future<void> writeProperty(String name, String value) =>
      _inner.writeProperty(name, value);

  @override
  Stream<void> get onRemoved => _inner.onRemoved;

  @override
  MeterMemory get memory => _inner.memory;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _release();
    }
  }
}
