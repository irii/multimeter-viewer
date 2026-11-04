import 'dart:async';

import 'package:unified_usb/unified_usb.dart';

import '../adapter.dart';
import '../serial_channel.dart';
import 'backend.dart';
import 'cdc_serial.dart';
import 'ftdi_serial.dart';

/// The serial protocol a USB device speaks.
enum UsbSerialDriver {
  /// FTDI USB-serial chip.
  ftdi,

  /// Standard USB CDC-ACM.
  cdc,
}

/// USB devices to offer, and how to talk to them.
class UsbFilter {
  const UsbFilter({
    required this.vendorId,
    this.productId,
    required this.driver,
    this.name,
  });

  final int vendorId;

  /// `null` matches any product of the vendor.
  final int? productId;
  final UsbSerialDriver driver;

  /// Replaces the device's own product name, e.g. where it is generic.
  final String? name;

  bool matches(int vendorId, int productId) =>
      this.vendorId == vendorId &&
      (this.productId == null || this.productId == productId);
}

/// The first of [filters] that accepts the device, if any.
UsbFilter? usbFilterFor(List<UsbFilter> filters, int vendorId, int productId) {
  for (final filter in filters) {
    if (filter.matches(vendorId, productId)) return filter;
  }
  return null;
}

/// [Adapter] over USB via `unified_usb`.
class UsbAdapter with AdapterQueue implements Adapter<UsbFilter> {
  final List<UsbFilter> _filters = [];

  UsbBackend? _backendInstance;
  Map<String, UsbDevice> _devices = {};

  /// Devices with an open channel.
  final Set<String> _inUse = {};

  /// Created lazily so a missing libusb / WebUSB shows up as a scan error.
  UsbBackend get _backend => _backendInstance ??= createUsbBackend();

  List<UsbDeviceFilter> get _backendFilters => [
    for (final filter in _filters)
      UsbDeviceFilter(vendorId: filter.vendorId, productId: filter.productId),
  ];

  UsbFilter? _filterFor(UsbDeviceDescriptor d) =>
      usbFilterFor(_filters, d.vendorId, d.productId);

  @override
  AdapterTransport get transport => AdapterTransport.usb;

  @override
  bool get canRequestDevice =>
      _backend.requestDeviceRequired && !usbPermissionsAutomatic(_backend);

  @override
  bool get autoSelectSingle => usbPermissionsAutomatic(_backend);

  @override
  Duration? get reprobeAfter => null;

  @override
  void attachFilter(UsbFilter filter) => _filters.add(filter);

  @override
  void detachFilter(UsbFilter filter) => _filters.remove(filter);

  @override
  Future<List<AdapterDevice>> listDevices({List<UsbFilter>? only}) async {
    if (_filters.isEmpty) return [];
    final filters = _backendFilters;
    await requestMissingUsbPermissions(_backend, filters);
    final devices = await _backend.getDevices(filters: filters);
    final found = <String, UsbDevice>{};
    for (final device in devices) {
      final id = _uniqueId(device.descriptor, found);
      // Keep the handle that is open.
      found[id] = _inUse.contains(id) ? _devices[id] ?? device : device;
    }
    _devices = found;
    return [
      for (final MapEntry(key: id, value: device) in found.entries)
        if (only == null ||
            usbFilterFor(
                  only,
                  device.descriptor.vendorId,
                  device.descriptor.productId,
                ) !=
                null)
          AdapterDevice(
            id: id,
            name: _deviceName(device.descriptor),
            inUse: _inUse.contains(id),
          ),
    ];
  }

  @override
  Future<void> requestDevice() async {
    if (!_backend.requestDeviceRequired) return;
    await _backend.requestDevice(filters: _backendFilters);
  }

  @override
  Future<SerialChannel> open(String deviceId) async {
    final device = _devices[deviceId];
    final filter = device == null ? null : _filterFor(device.descriptor);
    if (device == null || filter == null) {
      throw const AdapterException(AdapterError.deviceGone);
    }
    if (_inUse.contains(deviceId)) {
      throw const AdapterException(AdapterError.deviceInUse);
    }
    final SerialChannel serial = switch (filter.driver) {
      UsbSerialDriver.ftdi => await FtdiSerial.open(_backend, device),
      UsbSerialDriver.cdc => await CdcSerial.open(_backend, device),
    };
    _inUse.add(deviceId);
    return ReleasingChannel(serial, () => _inUse.remove(deviceId));
  }

  bool _isAccepted(UsbDevice d) => _filterFor(d.descriptor) != null;

  @override
  Stream<void> get onDevicesChanged {
    final UsbBackend backend;
    try {
      backend = _backend;
    } catch (_) {
      return const Stream.empty();
    }
    final controller = StreamController<void>();
    final subs = <StreamSubscription<UsbDevice>>[];
    controller
      ..onListen = () {
        subs
          ..add(
            backend.onDeviceConnected.where(_isAccepted).listen(controller.add),
          )
          ..add(
            backend.onDeviceDisconnected
                .where(_isAccepted)
                .listen(controller.add),
          );
      }
      ..onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    return controller.stream;
  }

  @override
  void dispose() {
    final backend = _backendInstance;
    if (backend != null) disposeUsbBackend(backend);
  }

  static String _uniqueId(UsbDeviceDescriptor d, Map<String, UsbDevice> taken) {
    final base =
        '${d.vendorId.toRadixString(16)}:${d.productId.toRadixString(16)}:'
        '${d.serialNumber ?? ''}';
    var id = base;
    for (var i = 2; taken.containsKey(id); i++) {
      id = '$base#$i';
    }
    return id;
  }

  String _deviceName(UsbDeviceDescriptor d) {
    final name =
        _filterFor(d)?.name ??
        d.productName ??
        '${d.vendorId.toRadixString(16).padLeft(4, '0')}:'
            '${d.productId.toRadixString(16).padLeft(4, '0')}';
    return d.serialNumber == null ? name : '$name (${d.serialNumber})';
  }
}
