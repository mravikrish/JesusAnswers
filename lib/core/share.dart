import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models/verse.dart';
import '../l10n/app_localizations.dart';
import 'theme/app_theme.dart';

/// Play Store listing. Works once the app is published under this applicationId
/// (android/app/build.gradle.kts). Override at build time if needed:
/// `--dart-define=PLAY_STORE_URL=https://…`
const playStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue: 'https://play.google.com/store/apps/details?id=com.jesusanswers.jesus_answers',
);

/// Appended to everything users share, so the person receiving a verse can get the app.
String shareFooter(AppLocalizations l) => '${l.appTitle} · ${l.tagline}\n${l.downloadApp} $playStoreUrl';

/// One verse as it is copied: the words and where they are from.
String verseText(Verse v) => '“${v.text}”\n— ${v.reference} (${v.translation})';

Future<void> shareVerse(Verse v, AppLocalizations l) =>
    SharePlus.instance.share(ShareParams(text: '${verseText(v)}\n\n${shareFooter(l)}'));

/// Copy or share just this verse — e.g. to send one verse on WhatsApp.
Future<void> showVerseActions(BuildContext context, Verse verse) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.ivoryCard,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(verse.reference, style: AppText.serif(20, weight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(l.copyVerse),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: verseText(verse)));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.copied), behavior: SnackBarBehavior.floating),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: Text(l.shareVerse),
            onTap: () {
              Navigator.pop(ctx);
              shareVerse(verse, l);
            },
          ),
        ],
      ),
    ),
  );
}
