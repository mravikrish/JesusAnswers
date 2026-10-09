import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/community.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/answer/safety.dart';
import '../../services/circle_service.dart';
import 'circle_chains.dart';
import 'circle_groups.dart';
import 'circle_praise.dart';
import 'circle_share.dart';

void _say(BuildContext context, String text) => sayInCircles(context, text);

/// From a ready prayer: picks one of the person's circles, asks for a note, and shares it there.
Future<void> sharePrayerToCircle(BuildContext context, WidgetRef ref, Prayer prayer) async {
  final l = AppLocalizations.of(context);
  final service = ref.read(circleServiceProvider);
  final circle = await pickCircle(context, service);
  if (circle == null || !context.mounted) return;
  final note = await askCircleNote(context, prayer.icon, prayer.title);
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
      (Icons.push_pin_rounded, l.circleInfoLeaders),
      (Icons.visibility_off_rounded, l.circleInfoPrivateRequests),
      (Icons.diversity_3_rounded, l.circleInfoGroups),
      (Icons.how_to_reg_rounded, l.circleInfoApproval),
      (Icons.celebration_rounded, l.circleInfoPraise),
      (Icons.link_rounded, l.circleInfoChains),
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
  const CirclesScreen({super.key, this.joinCode});

  /// Opened from an invite's QR code: asks to join this circle straight away.
  final String? joinCode;

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
    final code = widget.joinCode;
    if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => _join(code: code));
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

  /// A church, the home of its circles, or a circle for family and friends.
  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final church = await _askChurchOrCircle(context);
    if (church == null || !mounted) return;
    final title = church ? l.churchStart : l.circleStart;
    final answer = await _askTwo(
      context,
      title: title,
      first: church
          ? (l.churchName, l.churchNameHint, 60, TextCapitalization.words)
          : (l.circleName, l.circleNameHint, 60, TextCapitalization.words),
      second: (l.circleYourName, l.circleYourNameHint, 40, TextCapitalization.words),
      secondValue: ref.read(settingsProvider).name,
      action: title,
    );
    if (answer == null || !mounted) return;
    await _run(() => ref.read(circleServiceProvider).create(answer.$1, answer.$2, church: church));
  }

  /// [code]: from an invite's QR code, filled in.
  Future<void> _join({String? code}) async {
    final l = AppLocalizations.of(context);
    final answer = await _askTwo(
      context,
      title: l.circleJoin,
      first: (l.circleCode, 'K7P-3MX', 7, TextCapitalization.characters),
      firstValue: code == null ? '' : CircleService.showCode(code.toUpperCase()),
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
      if (circle.pending) {
        // Asked to join: a leader lets them in.
        _say(context, AppLocalizations.of(context).circleWaitingSent(circle.name));
        await _load();
        return;
      }
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
    // The server lists each church followed by its circles; a church's circle the person is in without
    // being in the church still belongs with the churches.
    final churches = [for (final c in _circles) if (c.church || c.parent != null) c];
    final own = [for (final c in _circles) if (!c.church && c.parent == null) c];
    return Scaffold(
      appBar: NightPanel.appBar(
        // Opened straight from an invite link, with nothing to go back to.
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(icon: const Icon(Icons.home_rounded), onPressed: () => context.go('/home')),
        title: Text(
          l.circlesTitle,
          style: AppText.serif(24, weight: FontWeight.w600, color: Colors.white),
        ),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.gold,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Praying together, under one sky: what a circle is, and the way in.
            NightPanel(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              child: Column(
                children: [
                  const _CirclesEmblem(),
                  const SizedBox(height: 16),
                  Text(
                    l.circlesIntro,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.45, color: Colors.white.withValues(alpha: 0.88)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.midnight,
                          ),
                          onPressed: _loading ? null : _start,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l.circleStartButton, textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                          ),
                          onPressed: _loading ? null : _join,
                          icon: const Icon(Icons.group_add_rounded, color: AppColors.goldSoft),
                          label: Text(l.circleJoin, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Churches, each with its circles beneath it; then the person's own circles.
            for (final (title, list) in [(l.circlesMyChurches, churches), (l.circlesMyCircles, own)])
              if (list.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.ember,
                    ),
                  ),
                ),
                for (final c in list) ...[
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: c.parent != null && churches.any((p) => p.church && p.name == c.parent) ? 44 : 20,
                      end: 20,
                    ),
                    child: _CircleCard(
                      circle: c,
                      hasNew: !c.pending && service.hasNew(c),
                      onTap: () => _open(c.code),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
            if (_offline && _circles.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  l.circleOffline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SoftCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    // Closed until the user opens it.
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.gold),
                    title: Text(l.circleInfoTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: const [CircleRules()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three people around a light: the picture at the top of Prayer Circles.
class _CirclesEmblem extends StatelessWidget {
  const _CirclesEmblem();

  @override
  Widget build(BuildContext context) {
    Widget person(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
        border: Border.all(color: AppColors.goldSoft.withValues(alpha: 0.5)),
      ),
      child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.goldSoft),
    );
    return SizedBox(
      width: 150,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, bottom: 4, child: person(46, 0.08)),
          Positioned(right: 0, bottom: 4, child: person(46, 0.08)),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold,
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 2)],
            ),
            child: const Icon(Icons.volunteer_activism_rounded, size: 34, color: AppColors.midnight),
          ),
        ],
      ),
    );
  }
}

/// The circle's own colour, the same each time: from its code.
Color _circleColor(String code) {
  const colors = [
    Color(0xFF3F5BA9), // blue
    Color(0xFF9A6A45), // ember
    Color(0xFF4E8C7A), // green
    Color(0xFF8B5A9E), // purple
    Color(0xFFC0794A), // amber
    Color(0xFF3E7FA8), // sea
    Color(0xFFB0545F), // rose
  ];
  return colors[code.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff) % colors.length];
}

/// One of the person's circles: its initial in its own colour, how many pray in it, and whether there's
/// something new.
class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle, required this.hasNew, required this.onTap});
  final CircleSummary circle;
  final bool hasNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = circle;
    // A church under the night sky, with its cross; a circle in its own colour, with its initial.
    final color = c.pending
        ? AppColors.inkSoft
        : c.church
        ? AppColors.navyLight
        : _circleColor(c.code);
    return Material(
      color: AppColors.ivoryCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: hasNew ? AppColors.gold : AppColors.sand, width: hasNew ? 1.5 : 1),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, Color.lerp(color, AppColors.midnight, 0.35)!],
                  ),
                ),
                child: c.pending
                    ? const Icon(Icons.hourglass_top_rounded, color: Colors.white)
                    : c.church
                    ? const Icon(Icons.church_rounded, color: AppColors.goldSoft, size: 28)
                    : Text(
                        c.name.characters.firstOrNull?.toUpperCase() ?? '?',
                        style: AppText.serif(26, weight: FontWeight.w700, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.parent != null)
                      Text('${c.parent} ›', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                    Text(c.name, style: AppText.serif(20, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          c.pending ? Icons.schedule_rounded : Icons.groups_rounded,
                          size: 16,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            c.pending ? l.circleWaitingLabel : l.circleMembers(c.members),
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    l.circleNew,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.midnight),
                  ),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
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

  /// For the next request: only leaders will see it; members won't see who asked.
  bool _forLeaders = false, _anonymous = false;

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
    if (!await _change(() => _service.ask(widget.code, text, forLeaders: _forLeaders, anonymous: _anonymous))) return;
    _text.clear();
    setState(() => _forLeaders = _anonymous = false);
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
                  child: Text(
                    g.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember, fontSize: 13),
                  ),
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
    final note = await askCircleNote(context, prayer.icon, prayer.title);
    if (note == null || !mounted) return;
    await _change(() => _service.sharePrayer(widget.code, prayer.id, note));
  }

  /// Plays the prayer; only once it has been prayed to the end does it count as joined.
  Future<void> _joinPrayer(CircleRequest r) async {
    final done = await context.push<bool>('/prayers/${r.prayerId}?along=1');
    if (done == true && mounted && !r.prayedByMe) await _change(() => _service.prayed(widget.code, r.id));
  }

  /// With a few words, if they like, on how God answered: for the praise wall.
  Future<void> _answered(CircleRequest r) async {
    final l = AppLocalizations.of(context);
    final testimony = await askCircleText(
      context,
      title: l.circleTestimonyTitle,
      hint: l.circleTestimonyHint,
      action: l.circleMarkAnswered,
      optional: true,
      icon: Icons.check_circle_rounded,
    );
    if (testimony == null || !mounted) return;
    if (await _change(() => _service.answered(widget.code, r.id, testimony: testimony)) && mounted) {
      _say(context, l.circleAnsweredThanks);
    }
  }

  /// Verses are shared from the Bible itself: press and hold one there.
  void _shareVerse() {
    context.push('/bible');
    _say(context, AppLocalizations.of(context).circleShareVerseHow);
  }

  void _showOnScreen(CircleDetail c) =>
      context.push('/circles/${c.code}/screen?name=${Uri.encodeQueryComponent(c.name)}');

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
                    Text(
                      l.circleMembersOf(c.members.length, CircleService.maxMembers),
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (c.owner)
                SwitchListTile(
                  secondary: const Icon(Icons.how_to_reg_rounded, color: AppColors.ember),
                  title: Text(l.circleApproval),
                  subtitle: Text(l.circleApprovalHint),
                  value: c.approval,
                  onChanged: (on) {
                    Navigator.pop(ctx);
                    _change(() => _service.setApproval(c.code, on: on));
                  },
                ),
              // Who asked to join, for a leader to let in or turn away.
              if (c.waiting.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  child: Text(
                    l.circleWaitingTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember),
                  ),
                ),
                for (final w in c.waiting)
                  ListTile(
                    leading: CircleInitial(w.name),
                    title: Text(w.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            if (!await _confirm(l.circleDeclineConfirm(w.name), l.circleDecline)) return;
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _change(() => _service.decline(c.code, w.id));
                          },
                          child: Text(l.circleDecline),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _change(() => _service.approve(c.code, w.id));
                          },
                          child: Text(l.circleApprove),
                        ),
                      ],
                    ),
                  ),
                const Divider(indent: 24, endIndent: 24),
              ],
              for (final m in c.members)
                ListTile(
                  leading: CircleInitial(m.name),
                  title: Text(m.me ? '${m.name} (${l.circleYou})' : m.name),
                  subtitle: m.owner
                      ? Text(l.circleOwner)
                      : m.leader
                      ? Text(
                          l.circleLeader,
                          style: const TextStyle(color: AppColors.ember, fontWeight: FontWeight.w600),
                        )
                      : null,
                  trailing: _memberMenu(ctx, c, m),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the reader may do to [m]: the owner can make or unmake leaders and remove anyone; a leader can
  /// remove members who aren't the owner or another leader. Null when nothing.
  Widget? _memberMenu(BuildContext sheet, CircleDetail c, CircleMember m) {
    final l = AppLocalizations.of(context);
    if (m.me || m.owner || !c.leader || (!c.owner && m.leader)) return null;
    Future<void> remove() async {
      if (!await _confirm(l.circleRemoveConfirm(m.name), l.circleRemoveMember)) return;
      if (sheet.mounted) Navigator.pop(sheet);
      await _change(() => _service.removeMember(c.code, m.id));
    }

    if (!c.owner) {
      return IconButton(
        tooltip: l.circleRemoveMember,
        icon: const Icon(Icons.person_remove_rounded, color: AppColors.inkSoft),
        onPressed: remove,
      );
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
      onSelected: (v) async {
        if (v == 'remove') return remove();
        if (sheet.mounted) Navigator.pop(sheet);
        await _change(() => _service.setLeader(c.code, m.id, on: !m.leader));
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'leader', child: Text(m.leader ? l.circleUnmakeLeader : l.circleMakeLeader)),
        PopupMenuItem(value: 'remove', child: Text(l.circleRemoveMember)),
      ],
    );
  }

  /// Someone who asked to join and waits for a leader.
  Widget _waitingView(CircleDetail c) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 48, color: AppColors.gold),
            const SizedBox(height: 16),
            Text(
              l.circleWaitingSent(c.name),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.45),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
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
                    },
              child: Text(l.circleStopWaiting),
            ),
          ],
        ),
      ),
    );
  }

  /// Prayer requests, shared prayers and verses: the circle's first page.
  Widget _prayersTab(CircleDetail c) {
    final l = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _InviteCard(
            code: c.code,
            members: c.members.length,
            onInvite: () => _invite(c),
            onShow: () => _showOnScreen(c),
          ),
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
          // Some requests are too personal for the whole church.
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                avatar: const Icon(Icons.lock_rounded, size: 18, color: AppColors.ember),
                label: Text(l.circleOnlyLeaders),
                selected: _forLeaders,
                onSelected: (v) => setState(() => _forLeaders = v),
              ),
              FilterChip(
                avatar: const Icon(Icons.visibility_off_rounded, size: 18, color: AppColors.ember),
                label: Text(l.circleNoName),
                selected: _anonymous,
                onSelected: (v) => setState(() => _anonymous = v),
              ),
            ],
          ),
          Wrap(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.ember),
                onPressed: _busy ? null : _sharePrayer,
                icon: const Icon(Icons.volunteer_activism_rounded, color: AppColors.gold),
                label: Text(l.circleSharePrayer),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.ember),
                onPressed: _busy ? null : _shareVerse,
                icon: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
                label: Text(l.circleShareVerse),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (c.requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.circleEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
              ),
            ),
          for (final r in c.requests) ...[
            _RequestCard(
              request: r,
              lead: c.leader,
              busy: _busy,
              onPin: () => _change(() => _service.pin(c.code, r.id, on: !r.pinned)),
              onPrayed: () => r.prayerId == null ? _change(() => _service.prayed(c.code, r.id)) : _joinPrayer(r),
              onHeart: () => _change(() => _service.heart(c.code, r.id, on: !r.heartedByMe)),
              onAnswered: () => _answered(r),
              onDelete: () => _change(() => _service.deleteRequest(c.code, r.id)),
              onReport: () async {
                if (await _change(() => _service.report(c.code, r.id)) && mounted) {
                  _say(context, l.circleReported);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// Joins one of the church's groups under the name the person has in the church.
  Future<void> _joinGroup(CircleDetail church, CircleGroup group) async {
    final l = AppLocalizations.of(context);
    final name = church.members.where((m) => m.me).firstOrNull?.name ?? ref.read(settingsProvider).name;
    setState(() => _busy = true);
    try {
      final joined = await _service.join(group.code, name);
      if (!mounted) return;
      if (joined.pending) {
        _say(context, l.circleWaitingSent(joined.name));
      } else {
        await context.push('/circles/${joined.code}');
      }
    } catch (e) {
      if (mounted) _say(context, circleProblemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _circle;
    // A church's groups have a page of their own; a group can't have groups.
    // Only a church holds circles.
    final groups = c != null && c.church;
    final tabs = c == null || c.pending
        ? const <String>[]
        : [l.circleTabPrayers, l.circleTabPraise, l.circleTabChains, if (groups) l.circleTabGroups];
    final busy = _busy ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2);

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A group: its church, one tap away for those in it.
            if (c?.parentName != null)
              GestureDetector(
                onTap: c!.parentCode == null ? null : () => context.push('/circles/${c.parentCode}'),
                child: Text('${c.parentName} ›', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              ),
            Text(c?.name ?? l.circlesTitle, style: AppText.serif(24, weight: FontWeight.w600)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabs.isEmpty ? 2 : 50),
          child: Column(
            children: [
              if (tabs.isNotEmpty)
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.ember,
                  indicatorColor: AppColors.gold,
                  tabs: [for (final label in tabs) Tab(height: 48, text: label)],
                ),
              busy,
            ],
          ),
        ),
        actions: [
          if (c != null && !c.pending) ...[
            IconButton(
              tooltip: l.circleInvite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _invite(c),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'members' => _members(c),
                'screen' => _showOnScreen(c),
                'rules' => _rules(),
                _ => _leave(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'members',
                  child: Text(
                    c.waiting.isEmpty
                        ? '${l.circleMembersTitle} (${c.members.length}/${CircleService.maxMembers})'
                        : '${l.circleMembersTitle} · ${l.circleWaitingTitle} (${c.waiting.length})',
                  ),
                ),
                PopupMenuItem(value: 'screen', child: Text(l.circleShowScreen)),
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
          : c.pending
          ? _waitingView(c)
          : TabBarView(
              children: [
                _prayersTab(c),
                CirclePraiseTab(circle: c, busy: _busy, change: _change, onRefresh: _load),
                CircleChainsTab(circle: c, busy: _busy, change: _change, onRefresh: _load),
                if (groups)
                  CircleGroupsTab(
                    circle: c,
                    busy: _busy,
                    change: _change,
                    onRefresh: _load,
                    onJoin: (g) => _joinGroup(c, g),
                  ),
              ],
            ),
    );
    // The number of pages changes when a church gets its first group.
    return tabs.isEmpty
        ? scaffold
        : DefaultTabController(key: ValueKey(tabs.length), length: tabs.length, child: scaffold);
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code, required this.members, required this.onInvite, required this.onShow});
  final String code;
  final int members;
  final VoidCallback onInvite, onShow;

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
                Text(
                  l.circleMembersOf(members, CircleService.maxMembers),
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.circleShowScreen,
            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.ember, size: 30),
            onPressed: onShow,
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
    required this.lead,
    required this.busy,
    required this.onPin,
    required this.onPrayed,
    required this.onHeart,
    required this.onAnswered,
    required this.onDelete,
    required this.onReport,
  });

  final CircleRequest request;

  /// The reader is the circle's owner or a leader, so can pin and remove any request.
  final bool lead;
  final bool busy;
  final VoidCallback onPin, onPrayed, onHeart, onAnswered, onDelete, onReport;

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
    // A shared Bible verse, likewise from the reader's own Bible.
    final verseRef = r.verse;
    final verse = verseRef == null ? null : ref.watch(circleVerseProvider(verseRef)).value;
    void readChapter() {
      final at = RegExp(r'^(\S+) (\d+):(\d+)$').firstMatch(verseRef!);
      if (at != null) context.push('/bible/${at.group(1)}/${at.group(2)}?v=${at.group(3)}');
    }

    final menu = [
      if (lead) ('pin', r.pinned ? l.circleUnpin : l.circlePin, onPin),
      if (r.mine && !r.answered && !shared && verseRef == null) ('answered', l.circleMarkAnswered, onAnswered),
      if (r.mine || lead) ('delete', l.circleDelete, onDelete),
      if (!r.mine) ('report', l.circleReport, onReport),
    ];
    final card = SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      color: r.answered ? const Color(0xFFFFF4D6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.pinned)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.ember),
                  const SizedBox(width: 6),
                  Text(
                    l.circlePinned.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.ember,
                    ),
                  ),
                ],
              ),
            ),
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
                      if (r.leader)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsetsDirectional.only(start: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              l.circleLeader,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.midnight,
                              ),
                            ),
                          ),
                        ),
                      TextSpan(
                        text: '  ·  ${_when(context)}',
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
                  onSelected: (i) => menu[i].$3(),
                  itemBuilder: (_) => [
                    for (final (i, item) in menu.indexed) PopupMenuItem(value: i, child: Text(item.$2)),
                  ],
                ),
            ],
          ),
          // Who can see this, for the asker and the leaders (members never see these).
          for (final (show, icon, text) in [
            (r.forLeaders, Icons.lock_rounded, l.circleForLeadersNote),
            (r.anonymous && !r.nameHidden, Icons.visibility_off_rounded, l.circleAnonymousNote),
          ])
            if (show)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 15, color: AppColors.inkSoft),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                    ),
                  ],
                ),
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
          ] else if (verseRef != null) ...[
            if (r.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 8, 0),
                child: Text(r.text, style: const TextStyle(fontSize: 16, height: 1.45)),
              ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: readChapter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sand.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verse == null ? '…' : '“${verse.text}”',
                      style: AppText.serif(19, weight: FontWeight.w600, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      verse == null ? verseRef : '— ${verse.reference} (${verse.translation})',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember),
                    ),
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
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    l.circleAnswered,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ember),
                  ),
                ],
              ),
            ),
          if (r.testimony case final testimony?)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 8, 0),
              child: Text(testimony, style: AppText.serif(18, weight: FontWeight.w600, height: 1.35)),
            ),
          if (!r.mine && Safety.isCrisis(r.text))
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                l.circleReachOut(r.nameHidden ? l.circleSomeone : r.name),
                style: const TextStyle(color: AppColors.heart, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (verseRef != null)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.ember),
                  onPressed: readChapter,
                  icon: const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.gold),
                  label: Text(l.readChapter),
                )
              else if (shared)
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
              if (r.prayed > 0 && verseRef == null)
                Flexible(
                  child: Text(
                    shared
                        ? l.circleJoinedCount(compactCount(context, r.prayed))
                        : l.prayedCount(compactCount(context, r.prayed)),
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ),
              if (shared || verseRef != null) ...[
                const Spacer(),
                IconButton(
                  tooltip: l.circleLove,
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
            ],
          ),
        ],
      ),
    );
    // The circle's prayer focus stands out from the rest.
    return r.pinned
        ? DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: card,
          )
        : card;
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

class CircleInitial extends StatelessWidget {
  const CircleInitial(this.name, {super.key});
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

/// What to start: true for a church, false for a circle of family and friends; null when cancelled.
Future<bool?> _askChurchOrCircle(BuildContext context) {
  final l = AppLocalizations.of(context);
  Widget choice(BuildContext ctx, bool church, IconData icon, String title, String hint) => SoftCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.pop(ctx, church),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: church ? AppColors.midnight : AppColors.sand,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: church ? AppColors.goldSoft : AppColors.ember),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.serif(20, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(hint, style: const TextStyle(color: AppColors.inkSoft, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.circleStartTitle, style: AppText.serif(24, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            choice(ctx, true, Icons.church_rounded, l.circleStartChurch, l.circleStartChurchHint),
            const SizedBox(height: 12),
            choice(ctx, false, Icons.diversity_1_rounded, l.circleStartCircle, l.circleStartCircleHint),
          ],
        ),
      ),
    ),
  );
}

/// A dialog with two short fields; null when cancelled. [first] and [second] are (label, hint, max length, capitalization).
Future<(String, String)?> _askTwo(
  BuildContext context, {
  required String title,
  required (String, String, int, TextCapitalization) first,
  required (String, String, int, TextCapitalization) second,
  String firstValue = '',
  String secondValue = '',
  required String action,
}) => showDialog<(String, String)>(
  context: context,
  builder: (_) => _TwoFields(
    title: title,
    first: first,
    second: second,
    firstValue: firstValue,
    secondValue: secondValue,
    action: action,
  ),
);

/// The dialog of [_askTwo]. Its fields live as long as it does, through the closing animation too.
class _TwoFields extends StatefulWidget {
  const _TwoFields({
    required this.title,
    required this.first,
    required this.second,
    required this.firstValue,
    required this.secondValue,
    required this.action,
  });

  final String title, firstValue, secondValue, action;
  final (String, String, int, TextCapitalization) first, second;

  @override
  State<_TwoFields> createState() => _TwoFieldsState();
}

class _TwoFieldsState extends State<_TwoFields> {
  late final _a = TextEditingController(text: widget.firstValue);
  late final _b = TextEditingController(text: widget.secondValue);

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _a.text.trim().isNotEmpty && _b.text.trim().isNotEmpty;
    void done() => Navigator.pop(context, (_a.text.trim(), _b.text.trim()));
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
      title: Text(widget.title, style: AppText.serif(24, weight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [field(_a, widget.first), const SizedBox(height: 12), field(_b, widget.second, last: true)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: ready ? done : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
