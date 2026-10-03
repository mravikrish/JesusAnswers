package com.jesusanswers.jesus_answers

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.speech.tts.TextToSpeech
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    /// A save waiting for the storage permission (Android 9 and older only).
    private var pendingSave: Pair<File, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens the phone's own settings screens when the mic or the voice isn't working
        // (lib/core/device_settings.dart). Each tries the most specific screen first.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jesusanswers/settings").setMethodCallHandler { call, result ->
            val intents = when (call.method) {
                "app" -> listOf(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
                "voiceInput" -> listOf(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS), Intent(Settings.ACTION_SETTINGS))
                "ttsData" -> listOf(
                    Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
                    Intent("com.android.settings.TTS_SETTINGS"),
                    Intent(Settings.ACTION_SETTINGS),
                )
                else -> return@setMethodCallHandler result.notImplemented()
            }
            result.success(intents.any(::tryStart))
        }
        // Pictures gallery (lib/core/picture_share.dart): "whatsapp" sends a picture straight to
        // WhatsApp, where "My status" is first in the list, and returns false when WhatsApp isn't
        // installed; "save" puts it in the phone's gallery, in a JesusAnswers album.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jesusanswers/share").setMethodCallHandler { call, result ->
            val file = File(call.argument<String>("path")!!)
            if (call.method == "save") return@setMethodCallHandler save(file, result)
            if (call.method != "whatsapp") return@setMethodCallHandler result.notImplemented()
            val uri = FileProvider.getUriForFile(this, "$packageName.pictures", file)
            val sent = listOf("com.whatsapp", "com.whatsapp.w4b").filter(::isInstalled).any { pkg ->
                tryStart(
                    Intent(Intent.ACTION_SEND)
                        .setPackage(pkg)
                        .setType("image/*")
                        .putExtra(Intent.EXTRA_STREAM, uri)
                        .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                )
            }
            result.success(sent)
        }
    }

    private fun save(file: File, result: MethodChannel.Result) {
        val needsPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
        if (needsPermission) {
            pendingSave?.second?.success(false)
            pendingSave = file to result
            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), SAVE_PERMISSION_REQUEST)
            return
        }
        result.success(
            try {
                writeToGallery(file)
                true
            } catch (_: Exception) {
                false
            },
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SAVE_PERMISSION_REQUEST) return
        val (file, result) = pendingSave ?: return
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) save(file, result) else result.success(false)
    }

    private fun writeToGallery(file: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/JesusAnswers")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)!!
            try {
                contentResolver.openOutputStream(uri)!!.use { out -> file.inputStream().use { it.copyTo(out) } }
                contentResolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "JesusAnswers")
            dir.mkdirs()
            val target = File(dir, file.name)
            file.copyTo(target, overwrite = true)
            MediaScannerConnection.scanFile(this, arrayOf(target.path), arrayOf("image/png"), null)
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun tryStart(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    private companion object {
        const val SAVE_PERMISSION_REQUEST = 4021
    }
}
