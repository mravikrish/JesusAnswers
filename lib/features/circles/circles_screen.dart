import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/community.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/answer/safety.dart';
import '../../services/circle_service.dart';

String circleProblemText(AppLocalizations l, Object e) => switch (e) {
  CircleException(problem: CircleProblem.notFound) => l.circleNotFound,
  CircleException(problem: CircleProblem.full) => l.circleFull,
  CircleException(problem: CircleProblem.tooMany) => l.circleTooMany,
  CircleException(problem: CircleProblem.notAllowed) => l.circleNotAllowed,
  _ => l.circleOffline,
};

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

/// Asks for an optional note to go with [prayer]; null when cancelled.
Future<String?> _askNote(BuildContext context, Prayer prayer) {
  final l = AppLocalizations.of(context);
  final note = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(prayer.icon, color: AppColors.gold),
      title: Text(prayer.title, textAlign: TextAlign.center),
      content: TextField(
        controller: note,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l.circleNoteHint, counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx, note.text.trim()), child: Text(l.share)),
      ],
    ),
  ).whenComplete(note.dispose);
}

/// From a ready prayer: picks one of the person's circles, asks for a note, and shares it there.
Future<void> sharePrayerToCircle(BuildContext context, WidgetRef ref, Prayer prayer) async {
  final l = AppLocalizations.of(context);
  final service = ref.read(circleServiceProvider);
  var circles = service.saved;
  try {
    circles = await service.mine();
  } catch (_) {}
  if (!context.mounted) return;
  if (circles.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.circleNone),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: l.circlesTitle, onPressed: () => context.push('/circles')),
      ));
    return;
  }
  final circle = circles.length == 1
      ? circles.single
      : await showModalBottomSheet<CircleSummary>(
          context: context,
          showDragHandle: true,
          backgroundColor: AppColors.ivoryCard,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(l.circleChoose, style: AppText.serif(22, weight: FontWeight.w700)),
                ),
                for (final c in circles)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.sand,
                      child: Icon(Icons.groups_rounded, color: AppColors.ember),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(l.circleMembers(c.members)),
                    onTap: () => Navigator.pop(ctx, c),
                  ),
              ],
            ),
          ),
        );
  if (circle == null || !context.mounted) return;
  final note = await _askNote(context, prayer);
  if (note == null || !context.mounted) return;
  try {
    await service.sharePrayer(circle.code, prayer.id, note);
    if (context.mounted) _say(context, l.circleSharedTo(circle.name));
  } catch (e) {
    if (context.mounted) _say(context, circleProblemText(l, e));
  }
}

/// How prayer circles work: the limits and rules, so nobody is surprised by them.
class CircleRules extends StatelessWidget {
  const CircleRules({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rules = [
      (Icons.groups_rounded, l.circleInfoMembers(CircleService.maxMembers)),
      (Icons.diversity_3_rounded, l.circleInfoCircles(CircleService.maxCircles)),
      (Icons.volunteer_activism_rounded, l.circleInfoShare),
      (Icons.lock_rounded, l.circleInfoPrivate),
      (Icons.schedule_rounded, l.circleInfoDays(CircleService.keepDays)),
      (Icons.person_remove_rounded, l.circleInfoOwner),
      (Icons.flag_rounded, l.circleInfoReport),
      (Icons.logout_rounded, l.circleInfoLeave),
      (Icons.notifications_active_rounded, l.circleInfoPopups),
    ];
    return Column(
      children: [
        for (final (icon, text) in rules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Prayer Circles — the circles the person is in, and starting or joining one with a code.
class CirclesScreen extends ConsumerStatefulWidget {
  const CirclesScreen({super.key});

  @override
  ConsumerState<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends ConsumerState<CirclesScreen> {
  late List<CircleSummary> _circles = ref.read(circleServiceProvider).saved;
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(circleServiceProvider).mine();
      if (mounted) {
        setState(() {
          _circles = list;
          _offline = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String code) async {
    await context.push('/circles/$code');
    if (mounted) _load();
  }

  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final answer = await _askTwo(
      context,
      title: l.circleStart,
      first: (l.circleName, l.circleNameHint, 60, TextCapitalization.words),
      second: (l.circleYourName, l.circleYourNameHint, 40, TextCapitalization.words),
      secondValue: ref.read(settingsProvider).name,
      action: l.circleStart,
    );
    if (answer == null || !mounted) return;
    await _run(() => ref.read(circleServiceProvider).create(answer.$1, answer.$2));
  }

  Future<void> _join() async {
    final l = AppLocalizations.of(context);
    final answer = await _askTwo(
      context,
      title: l.circleJoin,
      first: (l.circleCode, 'K7P-3MX', 7, TextCapitalization.characters),
      second: (l.circleYourName, l.circleYourNameHint, 40, TextCapitalization.words),
      secondValue: ref.read(settingsProvider).name,
      action: l.circleJoin,
    );
    if (answer == null || !mounted) return;
    await _run(() => ref.read(circleServiceProvider).join(answer.$1, answer.$2));
  }

  /// Creates or joins, remembers the name for next time, and opens the circle.
  Future<void> _run(Future<CircleDetail> Function() action) async {
    setState(() => _loading = true);
    try {
      final circle = await action();
      if (!mounted) return;
      final me = circle.members.where((m) => m.me).firstOrNull;
      if (me != null && ref.read(settingsProvider).name.isEmpty) ref.read(settingsProvider.notifier).setName(me.name);
      await _open(circle.code);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _say(context, circleProblemText(AppLocalizations.of(context), e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = ref.read(circleServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.circlesTitle, style: AppText.serif(24, weight: FontWeight.w600)),
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(l.circlesIntro, style: const TextStyle(fontSize: 16, height: 1.45, color: AppColors.inkSoft)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _loading ? null : _start,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.circleStart, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.gold),
                    ),
                    onPressed: _loading ? null : _join,
                    icon: const Icon(Icons.group_add_rounded, color: AppColors.gold),
                    label: Text(l.circleJoin, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  // Open for someone new to circles; one tap away after that.
                  key: ValueKey(_circles.isEmpty),
                  initiallyExpanded: _circles.isEmpty,
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.gold),
                  title: Text(l.circleInfoTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: const [CircleRules()],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_offline && _circles.isEmpty)
              Text(l.circleOffline, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
            for (final c in _circles) ...[
              SoftCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.sand,
                    child: Icon(Icons.groups_rounded, color: AppColors.ember),
                  ),
                  title: Text(c.name, style: AppText.serif(20, weight: FontWeight.w700)),
                  subtitle: Text(l.circleMembers(c.members)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (service.hasNew(c))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                          child: Text(l.circleNew,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.midnight)),
                        ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                    ],
                  ),
                  onTap: () => _open(c.code),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// One circle: its code to invite others, and its prayer requests to pray for.
class CircleScreen extends ConsumerStatefulWidget {
  const CircleScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends ConsumerState<CircleScreen> {
  final _text = TextEditingController();
  CircleDetail? _circle;
  Object? _error;
  bool _busy = false;

  CircleService get _service => ref.read(circleServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _show(await _service.open(widget.code));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _show(CircleDetail circle) {
    if (!mounted) return;
    setState(() {
      _circle = circle;
      _error = null;
    });
    _service.markSeen(circle);
  }

  /// Runs a change; the server answers with the circle as it now is.
  Future<bool> _change(Future<CircleDetail> Function() action) async {
    setState(() => _busy = true);
    try {
      _show(await action());
      return true;
    } catch (e) {
      if (mounted) _say(context, circleProblemText(AppLocalizations.of(context), e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ask() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (!await _change(() => _service.ask(widget.code, text))) return;
    _text.clear();
    // Helplines first for someone who may be at risk, as everywhere else in the app.
    if (Safety.isCrisis(text) && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: CrisisCard()),
        ),
      );
    }
  }

  /// Picks a ready prayer, with an optional note, to pray together.
  Future<void> _sharePrayer() async {
    final l = AppLocalizations.of(context);
    final groups = await ref.read(prayerGroupsProvider.future);
    if (!mounted) return;
    final prayer = await showModalBottomSheet<Prayer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.ivoryCard,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(l.circlePickPrayer, style: AppText.serif(22, weight: FontWeight.w700)),
              ),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  child: Text(g.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember, fontSize: 13)),
                ),
                for (final p in g.prayers)
                  // Prayers for someone in danger lead with helplines; they aren't for sharing.
                  if (!p.crisis)
                    ListTile(
                      leading: Icon(p.icon, color: AppColors.gold),
                      title: Text(p.title),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
    if (prayer == null || !mounted) return;
    final note = await _askNote(context, prayer);
    if (note == null || !mounted) return;
    await _change(() => _service.sharePrayer(widget.code, prayer.id, note));
  }

  /// Plays the prayer; only once it has been prayed to the end does it count as joined.
  Future<void> _joinPrayer(CircleRequest r) async {
    final done = await context.push<bool>('/prayers/${r.prayerId}?along=1');
    if (done == true && mounted && !r.prayedByMe) await _change(() => _service.prayed(widget.code, r.id));
  }

  Future<void> _answered(CircleRequest r) async {
    if (await _change(() => _service.answered(widget.code, r.id)) && mounted) {
      _say(context, AppLocalizations.of(context).circleAnsweredThanks);
    }
  }

  void _invite(CircleDetail c) {
    final l = AppLocalizations.of(context);
    SharePlus.instance.share(
      ShareParams(text: '${l.circleInviteText(c.name, CircleService.showCode(c.code))}\n\n${shareFooter(l)}'),
    );
  }

  Future<bool> _confirm(String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.heart),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(l.circleLeaveConfirm, l.circleLeave) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.leave(widget.code);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _say(context, circleProblemText(l, e));
      }
    }
  }

  void _rules() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.ivoryCard,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            children: [
              Text(l.circleInfoTitle, style: AppText.serif(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              const CircleRules(),
            ],
          ),
        ),
      ),
    );
  }

  void _members(CircleDetail c) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.ivoryCard,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.circleMembersTitle, style: AppText.serif(22, weight: FontWeight.w700)),
                    Text(l.circleMembersOf(c.members.length, CircleService.maxMembers),
                        style: const TextStyle(color: AppColors.inkSoft)),
                  ],
                ),
              ),
              for (final m in c.members)
                ListTile(
                  leading: _Initial(m.name),
                  title: Text(m.me ? '${m.name} (${l.circleYou})' : m.name),
                  subtitle: m.owner ? Text(l.circleOwner) : null,
                  trailing: c.owner && !m.me
                      ? IconButton(
                          tooltip: l.circleRemoveMember,
                          icon: const Icon(Icons.person_remove_rounded, color: AppColors.inkSoft),
                          onPressed: () async {
                            if (!await _confirm(l.circleRemoveConfirm(m.name), l.circleRemoveMember)) return;
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _change(() => _service.removeMember(c.code, m.id));
                          },
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _circle;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? l.circlesTitle, style: AppText.serif(24, weight: FontWeight.w600)),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
        actions: [
          if (c != null) ...[
            IconButton(tooltip: l.circleInvite, icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: () => _invite(c)),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'members' => _members(c),
                'rules' => _rules(),
                _ => _leave(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'members',
                  child: Text('${l.circleMembersTitle} (${c.members.length}/${CircleService.maxMembers})'),
                ),
                PopupMenuItem(value: 'rules', child: Text(l.circleInfoTitle)),
                PopupMenuItem(value: 'leave', child: Text(l.circleLeave)),
              ],
            ),
          ],
        ],
      ),
      body: c == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(circleProblemText(l, _error!), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          if (_error case CircleException(problem: CircleProblem.offline))
                            FilledButton(
                              onPressed: () => setState(() {
                                _error = null;
                                _load();
                              }),
                              child: Text(MaterialLocalizations.of(context).refreshIndicatorSemanticLabel),
                            ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _InviteCard(code: c.code, members: c.members.length, onInvite: () => _invite(c)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _text,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l.circleAskHint,
                      counterText: '',
                      suffixIcon: IconButton(
                        tooltip: l.send,
                        icon: const Icon(Icons.send_rounded, color: AppColors.gold),
                        onPressed: _busy || _text.text.trim().isEmpty ? null : _ask,
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.ember),
                      onPressed: _busy ? null : _sharePrayer,
                      icon: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
                      label: Text(l.circleSharePrayer),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (c.requests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l.circleEmpty,
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, height: 1.4)),
                    ),
                  for (final r in c.requests) ...[
                    _RequestCard(
                      request: r,
                      owner: c.owner,
                      busy: _busy,
                      onPrayed: () => r.prayerId == null ? _change(() => _service.prayed(c.code, r.id)) : _joinPrayer(r),
                      onHeart: () => _change(() => _service.heart(c.code, r.id, on: !r.heartedByMe)),
                      onAnswered: () => _answered(r),
                      onDelete: () => _change(() => _service.deleteRequest(c.code, r.id)),
                      onReport: () async {
                        if (await _change(() => _service.report(c.code, r.id)) && context.mounted) {
                          _say(context, l.circleReported);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code, required this.members, required this.onInvite});
  final String code;
  final int members;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.circleInviteCode, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                SelectableText(
                  CircleService.showCode(code),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 3),
                ),
                Text(l.circleMembersOf(members, CircleService.maxMembers),
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.midnight,
            ),
            onPressed: onInvite,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(l.circleInvite),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    required this.request,
    required this.owner,
    required this.busy,
    required this.onPrayed,
    required this.onHeart,
    required this.onAnswered,
    required this.onDelete,
    required this.onReport,
  });

  final CircleRequest request;

  /// The reader started the circle, so can remove any request.
  final bool owner;
  final bool busy;
  final VoidCallback onPrayed, onHeart, onAnswered, onDelete, onReport;

  String _when(BuildContext context) {
    final at = request.at;
    final now = DateTime.now();
    final today = at.year == now.year && at.month == now.month && at.day == now.day;
    final locale = Localizations.localeOf(context).toString();
    try {
      return (today ? DateFormat.jm(locale) : DateFormat.MMMd(locale)).format(at);
    } catch (_) {
      return (today ? DateFormat.jm('en') : DateFormat.MMMd('en')).format(at);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final r = request;
    // A shared ready prayer, shown from the app's own copy in the reader's language.
    final shared = r.prayerId != null;
    final prayer = shared
        ? ref.watch(prayerGroupsProvider).value?.expand((g) => g.prayers).where((p) => p.id == r.prayerId).firstOrNull
        : null;
    final menu = [
      if (r.mine && !r.answered && !shared) ('answered', l.circleMarkAnswered, onAnswered),
      if (r.mine || owner) ('delete', l.circleDelete, onDelete),
      if (!r.mine) ('report', l.circleReport, onReport),
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      color: r.answered ? const Color(0xFFFFF4D6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Initial(r.name),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: r.mine ? l.circleYou : r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '  ·  ${_when(context)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                  ]),
                ),
              ),
              if (menu.isNotEmpty)
                PopupMenuButton<int>(
                  enabled: !busy,
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
                  onSelected: (i) => menu[i].$3(),
                  itemBuilder: (_) => [
                    for (final (i, item) in menu.indexed) PopupMenuItem(value: i, child: Text(item.$2)),
                  ],
                ),
            ],
          ),
          if (shared) ...[
            if (r.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 8, 0),
                child: Text(r.text, style: const TextStyle(fontSize: 16, height: 1.45)),
              ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: busy || prayer == null ? null : onPrayed,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sand.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(prayer?.icon ?? Icons.menu_book_rounded, color: AppColors.ember, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.circlePrayTogether, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                          Text(prayer?.title ?? '…', style: AppText.serif(19, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: AppColors.gold, size: 32),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 8, 4),
              child: Text(r.text, style: const TextStyle(fontSize: 16, height: 1.45)),
            ),
          if (r.answered)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(l.circleAnswered, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ember)),
              ]),
            ),
          if (!r.mine && Safety.isCrisis(r.text))
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(l.circleReachOut(r.name),
                  style: const TextStyle(color: AppColors.heart, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (shared)
                _JoinButton(joined: r.prayedByMe, enabled: !busy && prayer != null, onPressed: onPrayed)
              else if (r.prayedByMe)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: AppColors.sand,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: null,
                  icon: const Icon(Icons.check_rounded, size: 18, color: AppColors.ember),
                  label: Text(l.circleIPrayed),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(),
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                  onPressed: busy ? null : onPrayed,
                  icon: const Icon(Icons.volunteer_activism_rounded, size: 18, color: AppColors.gold),
                  label: Text(l.circleIPrayed),
                ),
              const SizedBox(width: 12),
              if (r.prayed > 0)
                Flexible(
                  child: Text(
                      shared
                          ? l.circleJoinedCount(compactCount(context, r.prayed))
                          : l.prayedCount(compactCount(context, r.prayed)),
                      style: const TextStyle(color: AppColors.inkSoft)),
                ),
              if (shared) ...[
                const Spacer(),
                IconButton(
                  tooltip: l.circleLove,
                  onPressed: busy ? null : onHeart,
                  icon: Icon(r.heartedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: AppColors.heart),
                ),
                if (r.hearts > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(compactCount(context, r.hearts), style: const TextStyle(color: AppColors.inkSoft)),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Join a shared prayer: it plays, and counts once prayed to the end. Joined people can pray it again.
class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.joined, required this.enabled, required this.onPressed});
  final bool joined, enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return joined
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: AppColors.sand,
              foregroundColor: AppColors.ink,
            ),
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.check_rounded, size: 18, color: AppColors.ember),
            label: Text(l.circleJoined),
          )
        : FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.midnight,
            ),
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(l.circleJoinPrayer),
          );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 16,
    backgroundColor: AppColors.sand,
    child: Text(
      name.characters.firstOrNull?.toUpperCase() ?? '?',
      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember),
    ),
  );
}

/// A dialog with two short fields; null when cancelled. [first] and [second] are (label, hint, max length, capitalization).
Future<(String, String)?> _askTwo(
  BuildContext context, {
  required String title,
  required (String, String, int, TextCapitalization) first,
  required (String, String, int, TextCapitalization) second,
  String secondValue = '',
  required String action,
}) {
  final a = TextEditingController();
  final b = TextEditingController(text: secondValue);
  return showDialog<(String, String)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final ready = a.text.trim().isNotEmpty && b.text.trim().isNotEmpty;
        void done() => Navigator.pop(ctx, (a.text.trim(), b.text.trim()));
        TextField field(TextEditingController c, (String, String, int, TextCapitalization) f, {bool last = false}) =>
            TextField(
              controller: c,
              autofocus: !last,
              maxLength: f.$3,
              textCapitalization: f.$4,
              textInputAction: last ? TextInputAction.done : TextInputAction.next,
              onChanged: (_) => setState(() {}),
              onSubmitted: last && ready ? (_) => done() : null,
              decoration: InputDecoration(labelText: f.$1, hintText: f.$2, counterText: ''),
            );
        return AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(title, style: AppText.serif(24, weight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [field(a, first), const SizedBox(height: 12), field(b, second, last: true)],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: ready ? done : null,
              child: Text(action),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    a.dispose();
    b.dispose();
  });
}
