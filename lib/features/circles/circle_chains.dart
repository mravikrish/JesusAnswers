import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/circle_service.dart';
import 'circle_share.dart';

/// A date or time in the reader's language, or in English where the phone has no such format.
String _format(BuildContext context, DateFormat Function(String locale) format, DateTime at) {
  try {
    return format(Localizations.localeOf(context).toString()).format(at);
  } catch (_) {
    return format('en').format(at);
  }
}

/// The phone's own reminder for a turn, so it comes without the app open and with no server.
String _reminderKey(PrayerChain chain, int slot) => 'chain:${chain.id}:$slot';

/// Prayer chains and fasting days: the pastor or a leader sets the turns; members take one, and their
/// phone reminds them when it comes.
class CircleChainsTab extends ConsumerWidget {
  const CircleChainsTab({
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
    final c = circle;

    Future<void> start() async {
      final chain = await _askChain(context);
      if (chain == null) return;
      await change(
        () => ref
            .read(circleServiceProvider)
            .createChain(
              c.code,
              title: chain.title,
              startsAt: chain.startsAt,
              slotMinutes: chain.slotMinutes,
              slots: chain.slots,
            ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(l.circleChainsIntro, style: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          if (c.leader) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: busy ? null : start,
              icon: const Icon(Icons.add_link_rounded),
              label: Text(l.circleNewChain),
            ),
            const SizedBox(height: 16),
          ],
          if (c.chains.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.circleChainsEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ),
          for (final chain in c.chains) ...[
            _ChainCard(circle: c, chain: chain, busy: busy, change: change),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ChainCard extends ConsumerWidget {
  const _ChainCard({required this.circle, required this.chain, required this.busy, required this.change});

  final CircleDetail circle;
  final PrayerChain chain;
  final bool busy;
  final CircleChange change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final service = ref.read(circleServiceProvider);
    final reminders = ref.read(reminderServiceProvider);
    final now = DateTime.now();
    final ended = !chain.endsAt.isAfter(now);

    String when(DateTime at) => chain.fasting
        ? _format(context, DateFormat.MMMEd, at)
        : '${_format(context, DateFormat.E, at)} ${_format(context, DateFormat.jm, at)}';
    final period = chain.fasting
        ? '${when(chain.startsAt)} – ${when(chain.slotStart(chain.slots - 1))}'
        : '${_format(context, DateFormat.MMMEd, chain.startsAt)} ${_format(context, DateFormat.jm, chain.startsAt)}'
              ' – ${when(chain.endsAt)}';

    Future<void> take(int slot) async {
      if (!await change(() => service.turn(circle.code, chain.id, slot, on: true))) return;
      // Asked only now, when there is a reason to.
      if (!await reminders.requestPermission()) return;
      await reminders.once(
        _reminderKey(chain, slot),
        chain.slotStart(slot),
        title: chain.fasting ? l.circleChainYourFast : l.circleChainYourTurn,
        body: '${chain.title} · ${circle.name}',
      );
    }

    Future<void> giveBack(int slot) async {
      if (await change(() => service.turn(circle.code, chain.id, slot, on: false))) {
        await reminders.cancelOnce(_reminderKey(chain, slot));
      }
    }

    Future<void> delete() async {
      if (!await change(() => service.deleteChain(circle.code, chain.id))) return;
      for (final t in chain.turns) {
        if (t.mine) await reminders.cancelOnce(_reminderKey(chain, t.slot));
      }
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(chain.fasting ? Icons.no_meals_rounded : Icons.link_rounded, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(chain.title, style: AppText.serif(21, weight: FontWeight.w700)),
              ),
              if (circle.leader)
                PopupMenuButton<int>(
                  enabled: !busy,
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
                  onSelected: (_) => delete(),
                  itemBuilder: (_) => [PopupMenuItem(value: 0, child: Text(l.circleDelete))],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 6),
            child: Text(
              ended ? '$period · ${l.circleChainEnded}' : period,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ),
          for (var slot = 0; slot < chain.slots; slot++)
            _SlotRow(
              label: when(chain.slotStart(slot)),
              turns: chain.turnsAt(slot),
              past: !chain.slotStart(slot + 1).isAfter(now),
              fasting: chain.fasting,
              busy: busy,
              onTake: () => take(slot),
              onGiveBack: () => giveBack(slot),
            ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.turns,
    required this.past,
    required this.fasting,
    required this.busy,
    required this.onTake,
    required this.onGiveBack,
  });

  final String label;
  final List<ChainTurn> turns;
  final bool past, fasting, busy;
  final VoidCallback onTake, onGiveBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mine = turns.any((t) => t.mine);
    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: mine ? AppColors.ember : AppColors.ink),
              ),
            ),
            Expanded(
              child: Text(
                turns.isEmpty ? l.circleChainNobody : [for (final t in turns) t.mine ? l.circleYou : t.name].join(', '),
                style: TextStyle(fontSize: 14, color: turns.isEmpty ? AppColors.inkSoft : AppColors.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!past)
              mine
                  ? TextButton(onPressed: busy ? null : onGiveBack, child: Text(l.circleChainGiveBack))
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        shape: const StadiumBorder(),
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.gold),
                      ),
                      onPressed: busy ? null : onTake,
                      child: Text(fasting ? l.circleChainFast : l.circleChainPray),
                    ),
          ],
        ),
      ),
    );
  }
}

typedef _NewChain = ({String title, DateTime startsAt, int slotMinutes, int slots});

/// What the new chain is for, hours of prayer or days of fasting, when it starts and how long it lasts.
Future<_NewChain?> _askChain(BuildContext context) {
  final l = AppLocalizations.of(context);
  final title = TextEditingController();
  final now = DateTime.now();
  var fasting = false;
  // From the next full hour; fasting from the start of tomorrow.
  var day = DateTime(now.year, now.month, now.day + (now.hour >= 23 ? 1 : 0));
  var time = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
  var count = 24;
  const hourChoices = [6, 12, 24, 48, 72], dayChoices = [1, 3, 7, 21, 40];

  return showDialog<_NewChain>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final startsAt = fasting
            ? DateTime(day.year, day.month, day.day)
            : DateTime(day.year, day.month, day.day, time.hour, time.minute);
        final choices = fasting ? dayChoices : hourChoices;
        final ready = title.text.trim().isNotEmpty;
        return AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(l.circleNewChain, style: AppText.serif(24, weight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l.circleChainTitle,
                    hintText: l.circleChainTitleHint,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l.circleChainHoursKind),
                      icon: const Icon(Icons.link_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l.circleChainDaysKind),
                      icon: const Icon(Icons.no_meals_rounded),
                    ),
                  ],
                  selected: {fasting},
                  onSelectionChanged: (v) => setState(() {
                    fasting = v.single;
                    count = fasting ? 3 : 24;
                    if (fasting && !day.isAfter(now)) day = DateTime(now.year, now.month, now.day + 1);
                  }),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded, color: AppColors.ember),
                  title: Text(l.circleChainStarts),
                  subtitle: Text(
                    fasting
                        ? _format(ctx, DateFormat.yMMMEd, startsAt)
                        : '${_format(ctx, DateFormat.yMMMEd, startsAt)} ${_format(ctx, DateFormat.jm, startsAt)}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: day,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked == null || !ctx.mounted) return;
                    final at = fasting ? null : await showTimePicker(context: ctx, initialTime: time);
                    setState(() {
                      day = picked;
                      if (at != null) time = at;
                    });
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: choices.contains(count) ? count : choices.first,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.timelapse_rounded)),
                  items: [
                    for (final n in choices)
                      DropdownMenuItem(value: n, child: Text(fasting ? l.circleChainDays(n) : l.circleChainHours(n))),
                  ],
                  onChanged: (n) => setState(() => count = n ?? count),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: ready
                  ? () => Navigator.pop(ctx, (
                      title: title.text.trim(),
                      startsAt: startsAt,
                      slotMinutes: fasting ? 1440 : 60,
                      slots: choices.contains(count) ? count : choices.first,
                    ))
                  : null,
              child: Text(l.circleNewChain),
            ),
          ],
        );
      },
    ),
  ).whenComplete(title.dispose);
}
