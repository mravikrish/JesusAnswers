import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/community_service.dart';
import '../theme/app_theme.dart';

/// 1,240 → "1.2K", in the reader's language where it has a short form.
String compactCount(BuildContext context, int n) {
  try {
    return NumberFormat.compact(locale: Localizations.localeOf(context).toString()).format(n);
  } catch (_) {
    return NumberFormat.compact(locale: 'en').format(n);
  }
}

/// A heart to love [item], and how many others loved, prayed or listened to it —
/// only real counts, and only once there are enough to mean something.
class CommunityBar extends ConsumerWidget {
  const CommunityBar({super.key, required this.item, this.dark = true});
  final String item;

  /// White on night screens and paintings.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final community = ref.watch(communityProvider);
    return ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        final loved = community.loved(item);
        final c = community.counts(item);
        String? part(int n, String Function(String) say) =>
            n >= CommunityService.shownFrom ? say(compactCount(context, n)) : null;
        final text = [
          ?part(c.hearts, l.lovedCount),
          ?part(c.prayed, l.prayedCount),
          ?part(c.listened, l.listenedCount),
        ].join(' · ');
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: l.love,
              onPressed: () => community.toggleHeart(item),
              icon: Icon(
                loved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: loved ? AppColors.redLetter : (dark ? Colors.white70 : AppColors.inkSoft),
              ),
            ),
            if (text.isNotEmpty)
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(color: dark ? Colors.white.withValues(alpha: 0.8) : AppColors.inkSoft, fontSize: 13),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Today 3,200 people prayed with you" — shown once enough people have.
class PrayedTodayLine extends ConsumerWidget {
  const PrayedTodayLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityProvider);
    return ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        if (community.today < CommunityService.shownFrom) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.groups_rounded, size: 18, color: AppColors.goldSoft),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).prayedWithYouToday(compactCount(context, community.today)),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
