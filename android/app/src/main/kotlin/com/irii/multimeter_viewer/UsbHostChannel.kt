package com.irii.multimeter_viewer

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge to Android's USB host API for the Dart side.
 *
 * Apps may not open /dev/bus/usb themselves, so devices are listed, granted
 * and opened here; Dart hands the file descriptor of the open connection to
 * libusb (libusb_wrap_sys_device), which then does all transfers.
 */
class UsbHostChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val methods = MethodChannel(messenger, "multimeter_viewer/usb")
    private val events = EventChannel(messenger, "multimeter_viewer/usb_events")
    private val connections = mutableMapOf<String, UsbDeviceConnection>()
    private val pendingPermissions = mutableMapOf<String, MutableList<MethodChannel.Result>>()
    private var eventSink: EventChannel.EventSink? = null

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) return
            val device = intent.usbDevice() ?: return
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            pendingPermissions.remove(device.deviceName)?.forEach { it.success(granted) }
        }
    }

    private val attachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val device = intent.usbDevice() ?: return
            val event = when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> "attached"
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    connections.remove(device.deviceName)?.close()
                    "detached"
                }
                else -> return
            }
            eventSink?.success(mapOf("event" to event, "device" to describe(device)))
        }
    }

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        register(permissionReceiver, IntentFilter(ACTION_USB_PERMISSION), exported = false)
        register(
            attachReceiver,
            IntentFilter().apply {
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            },
            // Protected system broadcasts.
            exported = true,
        )
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        context.unregisterReceiver(permissionReceiver)
        context.unregisterReceiver(attachReceiver)
        connections.values.forEach { it.close() }
        connections.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listDevices" -> result.success(usbManager.deviceList.values.map(::describe))
            "requestPermission" -> requestPermission(call.deviceName(), result)
            "open" -> open(call.deviceName(), result)
            "close" -> {
                connections.remove(call.deviceName())?.close()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val device = usbManager.deviceList[name]
            ?: return result.error("not_found", "USB device $name not found", null)
        if (usbManager.hasPermission(device)) return result.success(true)

        val waiting = pendingPermissions.getOrPut(name) { mutableListOf() }
        waiting.add(result)
        if (waiting.size > 1) return // dialog already showing

        // Explicit intent (required for mutable PendingIntents on Android 14+);
        // mutable so the system can add the device and the result.
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        usbManager.requestPermission(
            device,
            PendingIntent.getBroadcast(context, 0, intent, flags),
        )
    }

    private fun open(name: String, result: MethodChannel.Result) {
        val device = usbManager.deviceList[name]
            ?: return result.error("not_found", "USB device $name not found", null)
        if (!usbManager.hasPermission(device)) {
            return result.error("no_permission", "No permission for USB device $name", null)
        }
        connections.remove(name)?.close()
        val connection = usbManager.openDevice(device)
            ?: return result.error("open_failed", "Could not open USB device $name", null)
        connections[name] = connection
        result.success(connection.fileDescriptor)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /** Device as a map matching the Dart `UsbDeviceDescriptor`. */
    private fun describe(device: UsbDevice): Map<String, Any?> {
        val granted = usbManager.hasPermission(device)
        return mapOf(
            "name" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "deviceClass" to device.deviceClass,
            "deviceSubclass" to device.deviceSubclass,
            "deviceProtocol" to device.deviceProtocol,
            "manufacturerName" to device.manufacturerName,
            "productName" to device.productName,
            // Readable only with permission on Android 10+.
            "serialNumber" to if (granted) runCatching { device.serialNumber }.getOrNull() else null,
            "version" to device.version,
            "hasPermission" to granted,
            "configurations" to (0 until device.configurationCount).map { c ->
                val configuration = device.getConfiguration(c)
                mapOf(
                    "value" to configuration.id,
                    "name" to configuration.name,
                    "interfaces" to (0 until configuration.interfaceCount).map { i ->
                        val iface = configuration.getInterface(i)
                        mapOf(
                            "number" to iface.id,
                            "alternate" to iface.alternateSetting,
                            "class" to iface.interfaceClass,
                            "subclass" to iface.interfaceSubclass,
                            "protocol" to iface.interfaceProtocol,
                            "endpoints" to (0 until iface.endpointCount).map { e ->
                                val ep = iface.getEndpoint(e)
                                mapOf(
                                    "number" to ep.endpointNumber,
                                    "in" to (ep.direction == UsbConstants.USB_DIR_IN),
                                    "type" to when (ep.type) {
                                        UsbConstants.USB_ENDPOINT_XFER_BULK -> "bulk"
                                        UsbConstants.USB_ENDPOINT_XFER_INT -> "interrupt"
                                        UsbConstants.USB_ENDPOINT_XFER_ISOC -> "isochronous"
                                        else -> "control"
                                    },
                                    "maxPacketSize" to ep.maxPacketSize,
                                )
                            },
                        )
                    },
                )
            },
        )
    }

    private fun register(receiver: BroadcastReceiver, filter: IntentFilter, exported: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val flag = if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED
            context.registerReceiver(receiver, filter, flag)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    private fun MethodCall.deviceName(): String = argument<String>("name")!!

    @Suppress("DEPRECATION")
    private fun Intent.usbDevice(): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }

    companion object {
        private const val ACTION_USB_PERMISSION = "com.irii.multimeter_viewer.USB_PERMISSION"
    }
}
