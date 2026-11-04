/// USB on Android: devices are listed, granted and opened through Android's
/// USB host API (Kotlin side, `UsbHostChannel.kt`); transfers run through
/// libusb, which takes over the opened file descriptor.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:unified_usb/native_usb.dart';
import 'package:unified_usb/unified_usb.dart';

const _methods = MethodChannel('multimeter_viewer/usb');
const _events = EventChannel('multimeter_viewer/usb_events');

/// Name of the libusb build packaged in the APK (`lib/<abi>/`).
const androidLibusbName = 'libusb-1.0.so';

class AndroidUsbBackend implements UsbBackend {
  AndroidUsbBackend({UsbTransferMode transferMode = UsbTransferMode.sync})
    : _native = _initNative(transferMode);

  final NativeUsbBackend _native;

  static NativeUsbBackend _initNative(UsbTransferMode transferMode) {
    try {
      // Apps may not scan /dev/bus/usb; devices come from Android instead.
      NativeLibusb.deviceDiscovery = false;
      // Loaded by name (not handed over as a DynamicLibrary): the event
      // isolate of UsbTransferMode.asyncEvents opens the library itself.
      NativeLibusb.libraryPath = androidLibusbName;
    } on StateError {
      // Already initialized by an earlier backend in this process.
    }
    return NativeUsbBackend(transferMode: transferMode);
  }

  late final Stream<(String, AndroidUsbDevice)> _deviceEvents = _events
      .receiveBroadcastStream()
      .map((event) {
        final map = Map<Object?, Object?>.from(event as Map);
        return (
          map['event'] as String,
          AndroidUsbDevice._(
            Map<Object?, Object?>.from(map['device'] as Map),
            this,
          ),
        );
      })
      .asBroadcastStream();

  /// Like WebUSB, a device must be granted by the user ([requestDevice])
  /// before [getDevices] returns it.
  @override
  bool get requestDeviceRequired => true;

  @override
  bool get kernelDriverDetachSupported => _native.kernelDriverDetachSupported;

  /// Stops libusb's event isolate (see [disposeUsbBackend]).
  void dispose() => _native.dispose();

  Future<List<AndroidUsbDevice>> _list(List<UsbDeviceFilter> filters) async {
    final list = await _methods.invokeListMethod<Object?>('listDevices') ?? [];
    return [
      for (final entry in list)
        AndroidUsbDevice._(Map<Object?, Object?>.from(entry as Map), this),
    ].where((d) => filters.isEmpty || filters.any(d._matches)).toList();
  }

  @override
  Future<List<UsbDevice>> getDevices({
    List<UsbDeviceFilter> filters = const [],
  }) async => [
    for (final d in await _list(filters))
      if (d.hasPermission) d,
  ];

  /// Devices the permission dialog was already shown for, so a denied
  /// device is not asked again on every scan. Android gives a re-plugged
  /// device a new path, so it is asked again then.
  final Set<String> _asked = {};

  /// Asks once for permission for every matching device that has none.
  Future<void> requestMissingPermissions(List<UsbDeviceFilter> filters) async {
    final devices = await _list(filters);
    _asked.retainAll(devices.map((d) => d.name));
    for (final device in devices) {
      if (device.hasPermission || !_asked.add(device.name)) continue;
      await _methods.invokeMethod<bool>('requestPermission', {
        'name': device.name,
      });
    }
  }

  /// Shows Android's permission dialog for the first matching device that
  /// has not been granted yet.
  @override
  Future<UsbDevice> requestDevice({
    List<UsbDeviceFilter> filters = const [],
  }) async {
    final devices = await _list(filters);
    if (devices.isEmpty) {
      throw const UsbException('No matching USB device is connected.');
    }
    final device = devices.firstWhere(
      (d) => !d.hasPermission,
      orElse: () => devices.first,
    );
    final granted =
        await _methods.invokeMethod<bool>('requestPermission', {
          'name': device.name,
        }) ??
        false;
    if (!granted) {
      throw const UsbException('USB permission was denied.');
    }
    return device;
  }

  @override
  Stream<UsbDevice> get onDeviceConnected =>
      _deviceEvents.where((e) => e.$1 == 'attached').map((e) => e.$2);

  @override
  Stream<UsbDevice> get onDeviceDisconnected =>
      _deviceEvents.where((e) => e.$1 == 'detached').map((e) => e.$2);
}

/// A device known to Android. [open] obtains its file descriptor from the
/// Kotlin side and wraps it in libusb; all other calls go to that device.
class AndroidUsbDevice implements UsbDevice {
  AndroidUsbDevice._(Map<Object?, Object?> map, this._backend)
    : name = map['name']! as String,
      hasPermission = map['hasPermission'] as bool? ?? false,
      descriptor = _descriptorFrom(map);

  final AndroidUsbBackend _backend;

  /// Android's device path, e.g. `/dev/bus/usb/001/002`.
  final String name;
  final bool hasPermission;

  @override
  final UsbDeviceDescriptor descriptor;

  UsbDevice? _libusb;

  UsbDevice _open() =>
      _libusb ??
      (throw const UsbException('Device is not open; call open() first.'));

  @override
  bool get isOpen => _libusb != null;

  @override
  Future<void> open() async {
    if (_libusb != null) return;
    final fd = await _methods.invokeMethod<int>('open', {'name': name});
    if (fd == null) throw UsbException('Could not open $name.');
    try {
      _libusb = _backend._native.wrapSystemDevice(fd);
    } catch (_) {
      await _methods.invokeMethod<void>('close', {'name': name});
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    final device = _libusb;
    _libusb = null;
    try {
      await device?.close();
    } finally {
      // Closing the Android connection also closes the file descriptor.
      await _methods.invokeMethod<void>('close', {'name': name});
    }
  }

  @override
  Future<void> selectConfiguration(int configurationValue) =>
      _open().selectConfiguration(configurationValue);

  @override
  Future<void> claimInterface(int interfaceNumber) =>
      _open().claimInterface(interfaceNumber);

  @override
  Future<void> releaseInterface(int interfaceNumber) =>
      _open().releaseInterface(interfaceNumber);

  @override
  Future<void> selectAlternateInterface(
    int interfaceNumber,
    int alternateSetting,
  ) => _open().selectAlternateInterface(interfaceNumber, alternateSetting);

  @override
  Future<UsbInTransferResult> controlTransferIn(
    UsbControlSetup setup,
    int length,
  ) => _open().controlTransferIn(setup, length);

  @override
  Future<UsbOutTransferResult> controlTransferOut(
    UsbControlSetup setup,
    List<int> data,
  ) => _open().controlTransferOut(setup, data);

  @override
  Future<UsbInTransferResult> transferIn(int endpointNumber, int length) =>
      _open().transferIn(endpointNumber, length);

  @override
  Future<UsbOutTransferResult> transferOut(
    int endpointNumber,
    List<int> data,
  ) => _open().transferOut(endpointNumber, data);

  @override
  Future<void> reset() => _open().reset();

  @override
  Future<bool> isKernelDriverActive(int interfaceNumber) =>
      _open().isKernelDriverActive(interfaceNumber);

  @override
  Future<void> detachKernelDriver(int interfaceNumber) =>
      _open().detachKernelDriver(interfaceNumber);

  @override
  Future<void> attachKernelDriver(int interfaceNumber) =>
      _open().attachKernelDriver(interfaceNumber);

  @override
  Future<void> setAutoDetachKernelDriver(bool enable) =>
      _open().setAutoDetachKernelDriver(enable);

  /// Same physical device (Android's path is unique while plugged in).
  @override
  bool operator ==(Object other) =>
      other is AndroidUsbDevice && other.name == name;

  @override
  int get hashCode => name.hashCode;

  bool _matches(UsbDeviceFilter f) =>
      (f.vendorId == null || f.vendorId == descriptor.vendorId) &&
      (f.productId == null || f.productId == descriptor.productId) &&
      (f.classCode == null || f.classCode == descriptor.deviceClass) &&
      (f.subclassCode == null || f.subclassCode == descriptor.deviceSubclass) &&
      (f.protocolCode == null || f.protocolCode == descriptor.deviceProtocol) &&
      (f.serialNumber == null || f.serialNumber == descriptor.serialNumber);
}

UsbDeviceDescriptor _descriptorFrom(Map<Object?, Object?> map) {
  List<Map<Object?, Object?>> list(Object? value) => [
    for (final e in (value as List?) ?? const [])
      Map<Object?, Object?>.from(e as Map),
  ];

  // "2.00" -> 2, 0
  final version = (map['version'] as String? ?? '').split('.');
  int part(int i) => i < version.length ? int.tryParse(version[i]) ?? 0 : 0;

  return UsbDeviceDescriptor(
    vendorId: map['vendorId']! as int,
    productId: map['productId']! as int,
    deviceClass: map['deviceClass'] as int? ?? 0,
    deviceSubclass: map['deviceSubclass'] as int? ?? 0,
    deviceProtocol: map['deviceProtocol'] as int? ?? 0,
    manufacturerName: map['manufacturerName'] as String?,
    productName: map['productName'] as String?,
    serialNumber: map['serialNumber'] as String?,
    usbVersionMajor: part(0),
    usbVersionMinor: part(1) ~/ 10,
    configurations: [
      for (final c in list(map['configurations']))
        UsbConfigurationDescriptor(
          configurationValue: c['value'] as int? ?? 1,
          configurationName: c['name'] as String?,
          interfaces: _groupInterfaces(list(c['interfaces'])),
        ),
    ],
  );
}

/// Android lists each alternate setting as its own interface; group them by
/// interface number.
List<UsbInterfaceDescriptor> _groupInterfaces(
  List<Map<Object?, Object?>> interfaces,
) {
  final byNumber = <int, List<UsbAlternateInterface>>{};
  for (final i in interfaces) {
    (byNumber[i['number']! as int] ??= []).add(
      UsbAlternateInterface(
        alternateSetting: i['alternate'] as int? ?? 0,
        interfaceClass: i['class'] as int? ?? 0,
        interfaceSubclass: i['subclass'] as int? ?? 0,
        interfaceProtocol: i['protocol'] as int? ?? 0,
        endpoints: [
          for (final e in (i['endpoints'] as List? ?? const []))
            _endpoint(Map<Object?, Object?>.from(e as Map)),
        ],
      ),
    );
  }
  return [
    for (final entry in byNumber.entries)
      UsbInterfaceDescriptor(
        interfaceNumber: entry.key,
        alternates: entry.value,
      ),
  ];
}

UsbEndpointDescriptor _endpoint(Map<Object?, Object?> e) =>
    UsbEndpointDescriptor(
      endpointNumber: e['number']! as int,
      direction: e['in'] == true
          ? UsbDirection.inDirection
          : UsbDirection.outDirection,
      type: switch (e['type']) {
        'bulk' => UsbEndpointType.bulk,
        'interrupt' => UsbEndpointType.interrupt,
        'isochronous' => UsbEndpointType.isochronous,
        _ => UsbEndpointType.control,
      },
      maxPacketSize: e['maxPacketSize'] as int? ?? 64,
    );
