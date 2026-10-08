import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/community.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/circle_service.dart';
import 'circle_share.dart';
import 'circles_screen.dart' show CircleInitial;

/// The praise wall: answered prayers, with how God answered, and praise reports — kept for a year,
/// to encourage everyone.
class CirclePraiseTab extends ConsumerWidget {
  const CirclePraiseTab({
    super.key,
    required this.circle,
    required this.busy,
    required this.change,
    required this.onRefresh,
  });

  final CircleDetail circle;
  final bool busy;
  final CircleChange change;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final service = ref.read(circleServiceProvider);
    final c = circle;

    Future<void> share() async {
      final text = await askCircleText(
        context,
        title: l.circleSharePraise,
        hint: l.circlePraiseHint,
        action: l.share,
        icon: Icons.celebration_rounded,
      );
      if (text != null && text.isNotEmpty) await change(() => service.praise(c.code, text));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.midnight,
            ),
            onPressed: busy ? null : share,
            icon: const Icon(Icons.celebration_rounded),
            label: Text(l.circleSharePraise),
          ),
          const SizedBox(height: 16),
          if (c.praise.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.circlePraiseEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
              ),
            ),
          for (final r in c.praise) ...[
            _PraiseCard(
              request: r,
              lead: c.leader,
              busy: busy,
              onHeart: () => change(() => service.heart(c.code, r.id, on: !r.heartedByMe)),
              onDelete: () => change(() => service.deleteRequest(c.code, r.id)),
              onReport: () async {
                if (await change(() => service.report(c.code, r.id)) && context.mounted) {
                  sayInCircles(context, l.circleReported);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PraiseCard extends StatelessWidget {
  const _PraiseCard({
    required this.request,
    required this.lead,
    required this.busy,
    required this.onHeart,
    required this.onDelete,
    required this.onReport,
  });

  final CircleRequest request;
  final bool lead, busy;
  final VoidCallback onHeart, onDelete, onReport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = request;
    final locale = Localizations.localeOf(context).toString();
    String date(DateTime at) {
      try {
        return DateFormat.yMMMd(locale).format(at);
      } catch (_) {
        return DateFormat.yMMMd('en').format(at);
      }
    }

    final menu = [if (r.mine || lead) (l.circleDelete, onDelete), if (!r.mine) (l.circleReport, onReport)];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      color: const Color(0xFFFFF4D6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitial(r.nameHidden ? '?' : r.name),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: r.mine ? l.circleYou : (r.nameHidden ? l.circleSomeone : r.name),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ·  ${date(r.answeredAt ?? r.at)}',
                        style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              if (menu.isNotEmpty)
                PopupMenuButton<int>(
                  enabled: !busy,
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
                  onSelected: (i) => menu[i].$2(),
                  itemBuilder: (_) => [
                    for (final (i, item) in menu.indexed) PopupMenuItem(value: i, child: Text(item.$1)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(r.praise ? Icons.celebration_rounded : Icons.check_circle_rounded, size: 18, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                r.praise ? l.circlePraiseReport : l.circleAnswered,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (r.praise)
            Text(r.text, style: AppText.serif(19, weight: FontWeight.w600, height: 1.35))
          else ...[
            // What was asked, then how God answered.
            if (r.text.isNotEmpty)
              Text(r.text, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.inkSoft)),
            if (r.testimony case final testimony?) ...[
              const SizedBox(height: 6),
              Text(testimony, style: AppText.serif(19, weight: FontWeight.w600, height: 1.35)),
            ],
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: l.circlePraiseGod,
                onPressed: busy ? null : onHeart,
                icon: Icon(
                  r.heartedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: AppColors.heart,
                ),
              ),
              if (r.hearts > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(compactCount(context, r.hearts), style: const TextStyle(color: AppColors.inkSoft)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
