import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/answer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../theme/app_theme.dart';
import 'playback_controls.dart';

/// Bottom navigation: Home · Word · Pray · Journey · Profile.
/// Talking to Jesus starts from the big mic on Home (and the reply bar on an answer),
/// so the bar has no second mic; Profile sits here so language and voice are easy to find.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = shell.currentIndex <= 3; // Home, Word, Pray and Journey are night screens
    final fg = dark ? Colors.white : AppColors.ink;
    final bg = dark ? AppColors.midnight : AppColors.ivoryCard;

    Widget item(int branch, IconData icon, IconData active, String label) {
      final selected = shell.currentIndex == branch;
      return Expanded(
        child: InkResponse(
          onTap: () => shell.goBranch(branch, initialLocation: selected),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? active : icon, color: selected ? AppColors.gold : fg.withValues(alpha: 0.7)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: selected ? AppColors.gold : fg.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: fg.withValues(alpha: 0.08))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NowPlayingBar(dark: dark),
              SizedBox(
                height: 68,
                child: Row(
                  children: [
                    item(0, Icons.home_outlined, Icons.home_rounded, l.navHome),
                    item(1, Icons.menu_book_outlined, Icons.menu_book_rounded, l.navWord),
                    item(2, Icons.volunteer_activism_outlined, Icons.volunteer_activism, l.navPray),
                    item(3, Icons.favorite_border_rounded, Icons.favorite_rounded, l.navJourney),
                    item(4, Icons.person_outline_rounded, Icons.person_rounded, l.profileTitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the listening screen and, if the user said something, answers it.
Future<void> talk(BuildContext context, {String? mood}) async {
  final words = await context.push<String>('/listen');
  if (words == null || words.trim().isEmpty || !context.mounted) return;
  ask(context, words, mood: mood, spoken: true);
}

/// Starts the answer flow for a typed or spoken question (or a mood alone).
void ask(
  BuildContext context,
  String question, {
  String? mood,
  AnswerKind kind = AnswerKind.question,
  bool spoken = false,
}) {
  final lang = ProviderScope.containerOf(context, listen: false).read(settingsProvider).lang;
  context.push(
    '/processing',
    extra: AnswerRequest(question: question.trim(), lang: lang, mood: mood, kind: kind, spoken: spoken),
  );
}
