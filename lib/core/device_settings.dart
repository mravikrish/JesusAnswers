import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's own settings screens, for when the mic or the voice isn't working.
/// Android: MainActivity.kt. iOS only allows opening this app's page in Settings.
abstract final class DeviceSettings {
  static const _channel = MethodChannel('jesusanswers/settings');

  /// This app's page — where the microphone permission is switched back on.
  static Future<void> app() async {
    if (Platform.isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
    } else {
      await _open('app');
    }
  }

  /// Speech recognition settings, to add a language for voice input.
  static Future<void> voiceInput() => Platform.isIOS ? app() : _open('voiceInput');

  /// The text-to-speech engine's voice download screen.
  static Future<void> ttsVoices() => Platform.isIOS ? app() : _open('ttsData');

  static Future<void> _open(String screen) async {
    try {
      await _channel.invokeMethod<bool>(screen);
    } on PlatformException {
      // Nothing more we can open; the message on screen still says what to do.
    }
  }
}
