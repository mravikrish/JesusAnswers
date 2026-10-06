import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/languages.dart';
import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/divine_light.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/models/answer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../player/player_screen.dart';

/// The answer as a conversation: what you said, then His Word answering —
/// Scripture → Encouragement → Prayer — arriving gently one after another,
/// with a reply bar so the conversation can go on.
class AnswerScreen extends ConsumerStatefulWidget {
  const AnswerScreen({super.key, required this.id, this.autoplay = false});
  final String id;

  /// Read the answer aloud on arrival (the question was spoken).
  final bool autoplay;

  @override
  ConsumerState<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends ConsumerState<AnswerScreen> {
  late final _tts = ref.read(ttsProvider);
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(daysProvider).mark(); // a day with Jesus
    // Take the voice now: ref can't be used once the screen is closing, and without
    // this the voice kept playing after leaving. Warming it up also starts Listen sooner.
    _tts.warmUp(ref.read(settingsProvider).language);
    if (!widget.autoplay) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final answer = ref.read(journeyProvider.notifier).byId(widget.id);
      if (mounted && answer != null) _play(answer, AppLocalizations.of(context));
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _reply.dispose();
    super.dispose();
  }

  void _play(Answer a, AppLocalizations l) => readAloud(
        context,
        a.kind == AnswerKind.prayer
            ? [a.prayer]
            : [
                l.openingLine,
                for (final v in a.verses.take(1)) ...[v.reference, v.text],
                a.encouragement,
                a.prayer,
              ],
        languageFor(a.lang),
      );

  /// The full-screen player, one track per verse of the answer.
  Future<void> _openPlayer(Answer a, AppLocalizations l) async {
    await _tts.stop();
    if (!mounted) return;
    context.push(
      '/player',
      extra: PlayerArgs(
        lang: languageFor(a.lang),
        tracks: [for (final v in a.verses) PlayerTrack(verse: v, caption: l.godsWord, parts: [v.reference, v.text])],
      ),
    );
  }

  void _sendReply() {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    _reply.clear();
    _tts.stop();
    ask(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final answer = ref.watch(journeyProvider.select((list) => list.where((a) => a.id == widget.id).firstOrNull));
    if (answer == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.errorGeneric)));
    }
    final isPrayer = answer.kind == AnswerKind.prayer;
    var step = 0;
    Widget appear(Widget child) => _Appear(delay: Duration(milliseconds: 250 + 550 * step++), child: child);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        title: Text(isPrayer ? l.aPrayerForYou : l.yourAnswer, style: AppText.serif(24, weight: FontWeight.w600)),
        backgroundColor: const Color(0xF2F7E6C4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7E6C4), AppColors.ivory],
                  stops: [0, 0.35],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: DivineLight(color: AppColors.gold, intensity: 0.45))),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 24),
              children: [
                if (answer.question.isNotEmpty) appear(_YouBubble(label: l.you, text: answer.question)),
                if (answer.crisis) ...[const SizedBox(height: 16), appear(const CrisisCard())],
                const SizedBox(height: 18),
                if (answer.verses.isNotEmpty)
                  appear(_HisBubble(
                    showAvatar: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(icon: Icons.menu_book_rounded, title: l.godsWord),
                        const SizedBox(height: 12),
                        VerseQuote(verse: answer.verses.first, size: 22, shareable: true),
                        for (final v in answer.verses.skip(1)) ...[
                          const Divider(height: 28, color: AppColors.sand),
                          VerseQuote(verse: v, size: 18, shareable: true),
                        ],
                      ],
                    ),
                  )),
                if (!isPrayer) ...[
                  const SizedBox(height: 10),
                  appear(_HisBubble(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(icon: Icons.favorite_rounded, title: l.encouragement, color: AppColors.gold),
                        const SizedBox(height: 10),
                        Text(answer.encouragement, style: const TextStyle(fontSize: 16, height: 1.55)),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 18),
                appear(_PrayerCard(title: l.aPrayerForYou, prayer: answer.prayer)),
                const SizedBox(height: 18),
                appear(Column(
                  children: [
                    Text(
                      l.notAlone,
                      textAlign: TextAlign.center,
                      style: AppText.serif(19, color: AppColors.inkSoft).copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    PlaybackControls(
                      label: isPrayer ? l.playPrayer : l.playAnswer,
                      onPlay: () => _play(answer, l),
                      onExpand: answer.verses.isEmpty ? null : () => _openPlayer(answer, l),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => ref.read(journeyProvider.notifier).toggleFavorite(answer.id),
                          icon: Icon(
                            answer.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: answer.favorite ? AppColors.heart : AppColors.ink,
                          ),
                          label:
                              Text(answer.favorite ? l.saved : l.save, style: const TextStyle(color: AppColors.ink)),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText(answer, l))),
                          icon: const Icon(Icons.ios_share_rounded, color: AppColors.ink),
                          label: Text(l.share, style: const TextStyle(color: AppColors.ink)),
                        ),
                      ],
                    ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ReplyBar(
        controller: _reply,
        hint: l.keepTalking,
        onSend: _sendReply,
        onMic: () {
          _tts.stop();
          talk(context);
        },
      ),
    );
  }

  String _shareText(Answer a, AppLocalizations l) => [
        for (final v in a.verses.take(1)) '“${v.text}”\n— ${v.reference} (${v.translation})',
        if (a.kind == AnswerKind.question) a.encouragement,
        a.prayer,
        '\n${shareFooter(l)}',
      ].join('\n\n');
}

/// What the user said — on the right, like a sent message.
class _YouBubble extends StatelessWidget {
  const _YouBubble({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.navyLight, AppColors.navy]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(6),
                  ),
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
              ),
            ],
          ),
        ),
      );
}

/// His Word answering — on the left, beside today's painting of Jesus.
class _HisBubble extends ConsumerWidget {
  const _HisBubble({required this.child, this.showAvatar = false});
  final Widget child;
  final bool showAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painting = ref.watch(dailyPaintingProvider).value;
    const size = 40.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: size,
          child: !showAvatar
              ? null
              : Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                    boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 14)],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      painting?.asset ?? 'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                      alignment: painting?.focus ?? Alignment.center,
                      errorBuilder: (_, _, _) => Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ivoryCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(color: AppColors.goldSoft.withValues(alpha: 0.7)),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The prayer, set apart like a candle-lit card, ending in Amen.
class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.title, required this.prayer});
  final String title;
  final String prayer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3D9), Color(0xFFFFFBF2)],
          ),
          border: Border.all(color: AppColors.goldSoft),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 22)],
              ),
              child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.ember, size: 26),
            ),
            const SizedBox(height: 10),
            Text(title, style: AppText.serif(22, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(prayer, textAlign: TextAlign.center, style: AppText.serif(20, height: 1.5, color: AppColors.ink)),
          ],
        ),
      );
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.controller, required this.hint, required this.onSend, required this.onMic});
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        decoration: const BoxDecoration(
          color: AppColors.ivoryCard,
          border: Border(top: BorderSide(color: AppColors.sand)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: hint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.sand)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.sand)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded, color: AppColors.ember),
                        onPressed: onSend,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.gold,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: AppColors.gold,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onMic,
                    child: const SizedBox.square(
                      dimension: 48,
                      child: Icon(Icons.mic_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Fades and rises into place after [delay] — messages arriving one by one.
class _Appear extends StatefulWidget {
  const _Appear({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.title, this.color = AppColors.navy});
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(title, style: AppText.serif(20, weight: FontWeight.w700))),
        ],
      );
}
