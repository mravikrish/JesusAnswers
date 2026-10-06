import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Days with Jesus: the run of days and every day so far. Nothing on the very first visit.
class DaysCard extends ConsumerWidget {
  const DaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final days = ref.watch(daysProvider);
    return ListenableBuilder(
      listenable: days,
      builder: (context, _) {
        if (days.total == 0) return const SizedBox.shrink();
        final soft = TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: AppColors.goldSoft, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.daysWithJesus,
                          style: const TextStyle(
                              color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Text(l.daysInARow(days.streak), style: AppText.serif(22, color: Colors.white)),
                      Text(l.daysInAll(days.total), style: soft),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A milestone of days with Jesus, celebrated with its verse from the reader's own Bible, ready to share.
class MilestoneCard extends ConsumerWidget {
  const MilestoneCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final days = ref.watch(daysProvider);
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    return ListenableBuilder(
      listenable: days,
      builder: (context, _) {
        final milestone = days.pending;
        if (milestone == null) return const SizedBox.shrink();
        return FutureBuilder(
          future: ref.read(bibleProvider).fullVerse(milestone.ref, lang),
          builder: (context, snap) {
            final verse = snap.data;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 8, 8, 18),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                        onPressed: days.dismissMilestone,
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      ),
                    ),
                    const Icon(Icons.celebration_rounded, color: AppColors.goldSoft, size: 40),
                    const SizedBox(height: 8),
                    Text(l.milestoneTitle(milestone.days),
                        textAlign: TextAlign.center, style: AppText.serif(30, color: Colors.white)),
                    if (verse != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: VerseQuote(verse: verse, dark: true, size: 19, center: true),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.midnight),
                        onPressed: () => SharePlus.instance.share(ShareParams(
                          text: '${l.milestoneShare(milestone.days)}\n\n${verseText(verse)}\n\n${shareFooter(l)}',
                        )),
                        icon: const Icon(Icons.share_rounded),
                        label: Text(l.share),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
