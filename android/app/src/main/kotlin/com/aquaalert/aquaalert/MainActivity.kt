package com.aquaalert.aquaalert

import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The phone's own share sheet: the leak's card as a picture, with the same words
 * as the message beside it.
 *
 * Two ACTION_SENDs is a dozen lines here; a package for it would be a dependency,
 * a Gradle change and a version to keep up with, for an intent that has not
 * changed since Android 1. The chooser is a system component, so this needs no
 * <queries> entry even on Android 11 and later.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aquaalert/share")
            .setMethodCallHandler { call, result ->
                val send = Intent(Intent.ACTION_SEND).apply {
                    putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                    // What an email app puts on the subject line; chat apps ignore it.
                    putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject"))
                }
                when (call.method) {
                    "text" -> send.type = "text/plain"
                    "image" -> {
                        val png = call.argument<ByteArray>("png")
                        if (png == null) {
                            result.error("no-image", "share called with no png", null)
                            return@setMethodCallHandler
                        }
                        // One fixed name in the cache, overwritten every time: the
                        // sheet reads it before this returns, and the phone is free
                        // to clear the cache afterwards.
                        val dir = File(cacheDir, "share").apply { mkdirs() }
                        val file = File(dir, "aquaalert-leak.png")
                        file.writeBytes(png)
                        val uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file
                        )
                        send.type = "image/png"
                        send.putExtra(Intent.EXTRA_STREAM, uri)
                        // The same URI again as clip data: it is what the chooser
                        // reads to draw a thumbnail, and without it the sheet offers
                        // a nameless file icon instead of the card.
                        send.clipData = ClipData.newRawUri(null, uri)
                        // Granted to whichever app is picked, for this share only.
                        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                startActivity(Intent.createChooser(send, null))
                result.success(null)
            }
    }
}
