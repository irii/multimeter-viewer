package com.irii.multimeter_viewer

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var usbHost: UsbHostChannel? = null

    /** Pending "save as" request: file content and the Dart result. */
    private var pendingSave: Pair<ByteArray, MethodChannel.Result>? = null

    /** Compact view as picture-in-picture window. */
    private var compact: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        usbHost = UsbHostChannel(applicationContext, messenger)
        MethodChannel(messenger, "multimeter_viewer/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveDocument" -> saveDocument(
                    call.argument<String>("name")!!,
                    call.argument<String>("mimeType")!!,
                    call.argument<ByteArray>("bytes")!!,
                    result,
                )
                else -> result.notImplemented()
            }
        }
        compact = MethodChannel(messenger, "multimeter_viewer/compact").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enter" -> result.success(enterPictureInPicture())
                    "exit" -> {
                        leavePictureInPicture()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Shrinks the app to a floating window; `false` if not supported. */
    private fun enterPictureInPicture(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            !packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        ) {
            return false
        }
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(2, 1))
            .build()
        return try {
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            false // disabled by the user for this app
        }
    }

    /** Apps cannot expand their own window; bringing the task to the front does. */
    private fun leavePictureInPicture() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
            )
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        // Expanded or closed by the user.
        if (!isInPictureInPictureMode) compact?.invokeMethod("closed", null)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usbHost?.dispose()
        usbHost = null
        compact?.setMethodCallHandler(null)
        compact = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Lets the user pick where to save (Storage Access Framework). */
    private fun saveDocument(
        name: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        pendingSave?.second?.success(false)
        pendingSave = bytes to result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_TITLE, name)
        @Suppress("DEPRECATION")
        startActivityForResult(intent, SAVE_DOCUMENT_REQUEST)
    }

    @Deprecated("Deprecated in Java")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_DOCUMENT_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val (bytes, result) = pendingSave ?: return
        pendingSave = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Cannot write $uri")
            result.success(true)
        } catch (e: Exception) {
            result.error("write_failed", e.message, null)
        }
    }

    companion object {
        private const val SAVE_DOCUMENT_REQUEST = 0x28F
    }
}
