import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/languages.dart';

/// The Google Form that receives in-app feedback. Each submission becomes a row in the
/// form's response sheet, so no email address or server is exposed in the app.
///
/// From the form's pre-filled link
/// `https://docs.google.com/forms/d/e/FORM_ID/viewform?entry.MESSAGE=…&entry.DETAILS=…`
/// copy the form id and the two entry numbers here.
abstract final class FeedbackForm {
  static const formId = '1FAIpQLSdyO_RlNO6y78tY3IezCxxFvp5r8qfB0lgO4qEELJMhlx8DYg';
  static const messageEntry = '87759082';
  static const detailsEntry = '2072855514';

  static bool get configured => formId.isNotEmpty && messageEntry.isNotEmpty && detailsEntry.isNotEmpty;
}

/// Sends what the user wrote, with the app version, language and phone model
/// so a report like "the Telugu voice doesn't work" can be traced to a device.
class FeedbackService {
  FeedbackService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// True once the message has reached the form.
  Future<bool> send(String message, AppLanguage lang) async {
    if (!FeedbackForm.configured || message.trim().isEmpty) return false;
    try {
      final res = await _client
          .post(
            Uri.https('docs.google.com', '/forms/d/e/${FeedbackForm.formId}/formResponse'),
            body: {
              'entry.${FeedbackForm.messageEntry}': message.trim(),
              'entry.${FeedbackForm.detailsEntry}': await details(lang),
            },
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// "JesusAnswers 1.0.0 (1) · Telugu · Xiaomi Redmi Note 12 · Android 14"
  static Future<String> details(AppLanguage lang) async {
    final app = await PackageInfo.fromPlatform();
    return 'JesusAnswers ${app.version} (${app.buildNumber}) · ${lang.englishName} · ${await _device()}';
  }

  static Future<String> _device() async {
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model} · Android ${a.version.release}';
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        return '${i.utsname.machine} · iOS ${i.systemVersion}';
      }
    } catch (_) {
      // The message still goes, just without the phone model.
    }
    return defaultTargetPlatform.name;
  }
}
