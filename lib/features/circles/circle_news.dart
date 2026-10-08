import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/answer/safety.dart';
import '../../services/circle_service.dart';
import '../../services/voice/tts_service.dart' show Playback;
import 'circle_share.dart';

/// Shows what's new in the person's prayer circles as popups, one at a time, when the app opens or
/// comes back to the front: a request to pray for, a prayer to join, who prayed for them, answered prayers.
class CircleNewsPopups extends ConsumerStatefulWidget {
  const CircleNewsPopups({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CircleNewsPopups> createState() => _CircleNewsPopupsState();
}

class _CircleNewsPopupsState extends ConsumerState<CircleNewsPopups> with WidgetsBindingObserver {
  /// No more than this many popups at once; the rest wait in the circle, marked New.
  static const _maxPopups = 5;

  bool _checking = false;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final now = DateTime.now();
    if (_checking || (_lastCheck != null && now.difference(_lastCheck!) < const Duration(minutes: 1))) return;
    // Never over a prayer or reading that is playing.
    if (ref.read(ttsProvider).playback.value != Playback.idle) return;
    _checking = true;
    _lastCheck = now;
    try {
      final news = await ref.read(circleServiceProvider).news();
      final prayers = news.any((n) => n.prayerId != null)
          ? {for (final p in (await ref.read(prayerGroupsProvider.future)).expand((g) => g.prayers)) p.id: p}
          : const <String, Prayer>{};
      // A leader sees every crisis alert first, then the newest of the rest.
      final crisis = news.where((n) => n.crisis);
      final rest = news.where((n) => !n.crisis).toList().reversed.take(_maxPopups).toList().reversed;
      for (final n in [...crisis, ...rest]) {
        if (!mounted) return;
        // Opened the circle: the rest is there to see.
        if (await _show(n, prayers[n.prayerId])) return;
      }
    } catch (_) {
      // Offline or no server: nothing to show.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// True when the person went to the circle.
  Future<bool> _show(CircleNews n, Prayer? prayer) async {
    final l = AppLocalizations.of(context);
    final service = ref.read(circleServiceProvider);
    final id = n.requestId;
    // A shared prayer this version of the app doesn't have: nothing to join.
    if (n.kind == CircleNewsKind.prayer && prayer == null) return false;
    // Asked without a name.
    final who = n.name.isEmpty ? l.circleSomeone : n.name;

    final (IconData icon, String title) = switch (n.kind) {
      _ when n.crisis => (Icons.favorite_rounded, l.newsCrisis),
      CircleNewsKind.request => (Icons.volunteer_activism_rounded, l.newsAsked(who)),
      CircleNewsKind.prayer => (prayer!.icon, l.newsShared(n.name)),
      CircleNewsKind.prayed => (
        Icons.favorite_rounded,
        n.prayerId == null ? l.newsPrayed(n.count) : l.newsJoinedPrayer(n.count),
      ),
      CircleNewsKind.answered => (Icons.check_circle_rounded, l.newsAnswered(who)),
      CircleNewsKind.joined => (
        Icons.group_add_rounded,
        n.count > 1 ? l.newsJoinedMany(n.name, n.count - 1) : l.newsJoined(n.name),
      ),
      CircleNewsKind.verse => (Icons.menu_book_rounded, l.newsVerse(n.name)),
      CircleNewsKind.waiting => (Icons.how_to_reg_rounded, l.newsWaiting(n.count, n.name)),
      CircleNewsKind.approved => (Icons.celebration_rounded, l.newsApproved(n.circleName)),
      CircleNewsKind.chain => (Icons.link_rounded, l.newsChain(n.name)),
      CircleNewsKind.group => (Icons.diversity_3_rounded, l.newsGroup(n.name)),
    };
    // A shared verse, from the reader's own Bible.
    final verse = n.verse == null ? null : await ref.read(circleVerseProvider(n.verse!).future);
    if (!mounted) return false;

    // (label, primary, what it does once the popup closes)
    final actions = <(String, bool, Future<void> Function()?)>[
      if (n.crisis) ...[
        (l.newsOpen, false, () async => context.push('/circles/${n.circle}')),
        (l.newsReachOut, true, null),
      ] else ...[
        switch (n.kind) {
          CircleNewsKind.request || CircleNewsKind.prayer => (l.newsLater, false, null),
          // The new group, to join from its church's Groups.
          _ => (l.newsOpen, false, () async => context.push('/circles/${n.circle}')),
        },
        switch (n.kind) {
          CircleNewsKind.request => (l.circleIPrayed, true, () async => service.prayed(n.circle, id!)),
          CircleNewsKind.prayer => (
            l.circleJoinPrayer,
            true,
            () async {
              final done = await context.push<bool>('/prayers/${n.prayerId}?along=1');
              if (done == true) await service.prayed(n.circle, id!);
            },
          ),
          _ => (l.newsAmen, true, null),
        },
      ],
    ];

    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ivoryCard,
        icon: Icon(icon, color: n.crisis ? AppColors.heart : AppColors.gold, size: 36),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
              child: Text(
                n.circleName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ember),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.serif(22, weight: FontWeight.w700),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (n.text.isNotEmpty)
                Text(n.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.45)),
              if (verse != null) ...[
                if (n.text.isNotEmpty) const SizedBox(height: 12),
                Text(
                  '“${verse.text}”',
                  textAlign: TextAlign.center,
                  style: AppText.serif(19, weight: FontWeight.w600, height: 1.35),
                ),
                const SizedBox(height: 4),
                Text(
                  '— ${verse.reference}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember),
                ),
              ],
              // How God answered.
              if (n.testimony case final testimony?) ...[
                const SizedBox(height: 12),
                Text(
                  testimony,
                  textAlign: TextAlign.center,
                  style: AppText.serif(19, weight: FontWeight.w600, height: 1.35),
                ),
              ],
              if (prayer != null) ...[
                if (n.text.isNotEmpty) const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(prayer.icon, color: AppColors.ember),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(prayer.title, style: AppText.serif(19, weight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
              if (n.crisis || (n.kind == CircleNewsKind.request && Safety.isCrisis(n.text))) ...[
                const SizedBox(height: 12),
                Text(
                  l.circleReachOut(who),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.heart, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          for (final (i, (label, primary, _)) in actions.indexed)
            primary
                ? FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.midnight),
                    onPressed: () => Navigator.pop(ctx, i),
                    child: Text(label),
                  )
                : TextButton(onPressed: () => Navigator.pop(ctx, i), child: Text(label)),
        ],
      ),
    );
    if (chosen == null || !mounted) return false;
    try {
      await actions[chosen].$3?.call();
    } catch (_) {
      // Couldn't reach the server: the request is still there in the circle.
    }
    return chosen == 0 && actions[0].$3 != null;
  }
}
