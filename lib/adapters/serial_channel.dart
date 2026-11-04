/// Byte transport to a device (USB serial, Bluetooth LE, fakes in tests).
abstract interface class SerialChannel {
  Future<void> write(List<int> data);

  /// Returns whatever bytes have arrived; may be empty.
  Future<List<int>> read();

  /// Fires when the underlying device is unplugged.
  Stream<void> get onRemoved;

  Future<void> close();
}

/// Runs a callback when the channel is closed, so an adapter can mark its
/// device as free again.
class ReleasingChannel implements SerialChannel {
  ReleasingChannel(this._inner, this._release);

  final SerialChannel _inner;
  final void Function() _release;

  @override
  Future<void> write(List<int> data) => _inner.write(data);

  @override
  Future<List<int>> read() => _inner.read();

  @override
  Stream<void> get onRemoved => _inner.onRemoved;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _release();
    }
  }
}
