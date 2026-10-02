import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'languages.dart';

/// Where "Send feedback" goes. Override at build time: `--dart-define=FEEDBACK_EMAIL=…`
const feedbackEmail = String.fromEnvironment('FEEDBACK_EMAIL', defaultValue: 'mravikrish@gmail.com');

/// Opens the phone's email app with a message to us. Below the space for their words it adds
/// the app version, language and phone model, so a report like "Telugu voice doesn't work"
/// can be traced to a device. Nothing is sent unless the user presses Send in their email app.
Future<void> sendFeedback(BuildContext context, AppLanguage lang) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final app = await PackageInfo.fromPlatform();
  final details = '${l.appTitle} ${app.version} (${app.buildNumber}) · ${lang.englishName} · ${await _device()}';
  // Encode by hand: Uri's queryParameters turns spaces into "+", which some mail apps show as-is.
  final uri = Uri(
    scheme: 'mailto',
    path: feedbackEmail,
    query: 'subject=${Uri.encodeComponent('${l.appTitle} feedback (${app.version})')}'
        '&body=${Uri.encodeComponent('\n\n\n—\n$details')}',
  );
  final opened = await launchUrl(uri).catchError((_) => false);
  if (!opened) {
    messenger.showSnackBar(SnackBar(
      content: Text(l.noEmailApp(feedbackEmail)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 8),
    ));
  }
}

Future<String> _device() async {
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
    // Fall through: the feedback still goes, just without the phone model.
  }
  return defaultTargetPlatform.name;
}
