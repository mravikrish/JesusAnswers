import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/circle_service.dart';
import 'circle_share.dart';

/// A church's groups — youth, fellowships, home groups — each a circle of its own. The church's members
/// join one with a tap, no code needed; the pastor or a leader adds them.
class CircleGroupsTab extends ConsumerWidget {
  const CircleGroupsTab({
    super.key,
    required this.circle,
    required this.busy,
    required this.change,
    required this.onRefresh,
    required this.onJoin,
  });

  final CircleDetail circle;
  final bool busy;
  final CircleChange change;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CircleGroup group) onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = circle;

    Future<void> add() async {
      final name = await askCircleText(
        context,
        title: l.circleAddGroup,
        hint: l.circleGroupNameHint,
        action: l.circleAddGroup,
        maxLength: 60,
        lines: 1,
        icon: Icons.diversity_3_rounded,
      );
      if (name != null && name.isNotEmpty) {
        await change(() => ref.read(circleServiceProvider).createGroup(c.code, name));
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(l.circleGroupsIntro, style: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          if (c.leader) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: busy ? null : add,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.circleAddGroup),
            ),
            const SizedBox(height: 16),
          ],
          if (c.groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.circleNoGroups,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ),
          for (final g in c.groups) ...[
            SoftCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.sand,
                  child: Icon(Icons.diversity_3_rounded, color: AppColors.ember),
                ),
                title: Text(g.name, style: AppText.serif(20, weight: FontWeight.w700)),
                subtitle: Text(g.pending ? l.circleWaitingLabel : l.circleMembers(g.members)),
                trailing: g.joined
                    ? const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft)
                    : g.pending
                    ? const Icon(Icons.hourglass_top_rounded, color: AppColors.inkSoft)
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.midnight,
                        ),
                        onPressed: busy ? null : () => onJoin(g),
                        child: Text(l.circleJoinGroup),
                      ),
                onTap: g.joined || g.pending ? () => context.push('/circles/${g.code}') : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
