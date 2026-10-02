package com.jesusanswers.jesus_answers

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }

    private fun tryStart(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
