import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/picture_share.dart';
import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../pictures/pictures_screen.dart';

/// Ready Prayers — prayers for every day, every need and every occasion, by
/// group, each with a painting of Jesus. Tap one to hear it; "For someone"
/// lists the ones that can be prayed for another person by name.
class PrayersScreen extends ConsumerStatefulWidget {
  const PrayersScreen({super.key});

  @override
  ConsumerState<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends ConsumerState<PrayersScreen> {
  final _search = TextEditingController();
  bool _forSomeone = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = ref.watch(prayerGroupsProvider).value;
    final query = _search.text.trim().toLowerCase();
    bool shown(PrayerGroup g, Prayer p) =>
        (!_forSomeone || p.canPrayForSomeone) &&
        (query.isEmpty ||
            p.title.toLowerCase().contains(query) ||
            (p.forTitle?.toLowerCase().contains(query) ?? false) ||
            g.title.toLowerCase().contains(query));
    final visible = [
      for (final g in groups ?? const <PrayerGroup>[])
        if (g.prayers.where((p) => shown(g, p)).toList() case final list when list.isNotEmpty) (g, list),
    ];

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        title: Text(l.readyPrayers, style: AppText.serif(26, weight: FontWeight.w600)),
      ),
      body: groups == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
              children: [
                Text(l.readyPrayersHint, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.searchPrayers,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: _ForWhomToggle(forSomeone: _forSomeone, onChanged: (v) => setState(() => _forSomeone = v)),
                ),
                if (_forSomeone) ...[
                  const SizedBox(height: 8),
                  Text(l.forSomeoneHint,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                const Center(child: VoiceToggle.prayers()),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(l.noPrayersFound,
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
                  ),
                for (final (g, list) in visible) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
                    child: Text(g.title, style: AppText.serif(22, weight: FontWeight.w700)),
                  ),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.sand),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, p) in list.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 72, color: AppColors.sand),
                          _PrayerTile(prayer: p, forSomeone: _forSomeone),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// The prayer's painting as a small round picture with its icon on it, its title, and play.
class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.prayer, required this.forSomeone});
  final Prayer prayer;
  final bool forSomeone;

  @override
  Widget build(BuildContext context) {
    final picture = prayer.picture;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: SizedBox.square(
        dimension: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: picture == null
                  ? const ColoredBox(color: AppColors.goldSoft)
                  : Image.asset(picture.asset, fit: BoxFit.cover, alignment: picture.focus, cacheWidth: 144),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.white,
                child: Icon(prayer.icon, color: AppColors.ember, size: 14),
              ),
            ),
          ],
        ),
      ),
      title: Text(
        forSomeone ? prayer.forTitle ?? prayer.title : prayer.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prayer.canPrayForSomeone && !forSomeone)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.group_rounded, size: 18, color: AppColors.inkSoft),
            ),
          const Icon(Icons.play_circle_outline_rounded, color: AppColors.gold),
        ],
      ),
      onTap: () => context.push('/prayers/${prayer.id}${forSomeone ? '?for=1' : ''}'),
    );
  }
}

/// For me / For someone.
class _ForWhomToggle extends StatelessWidget {
  const _ForWhomToggle({required this.forSomeone, required this.onChanged, this.dark = false});
  final bool forSomeone;
  final ValueChanged<bool> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.gold.withValues(alpha: dark ? 0.5 : 0.22),
        selectedForegroundColor: dark ? Colors.white : AppColors.ink,
        foregroundColor: dark ? Colors.white70 : AppColors.inkSoft,
        side: BorderSide(color: dark ? Colors.white38 : AppColors.sand),
      ),
      segments: [
        ButtonSegment(value: false, icon: const Icon(Icons.person_rounded), label: Text(l.forMe)),
        ButtonSegment(value: true, icon: const Icon(Icons.group_rounded), label: Text(l.forSomeone)),
      ],
      selected: {forSomeone},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// One prayer over its painting of Jesus, read aloud as soon as it opens in the
/// man's or woman's voice chosen, with soft music under it. A prayer that can be
/// prayed for someone takes their name, and any prayer can be sent on WhatsApp,
/// as a WhatsApp Status picture, or anywhere.
class PrayerReadScreen extends ConsumerStatefulWidget {
  const PrayerReadScreen({super.key, required this.id, this.forSomeone = false});
  final String id;
  final bool forSomeone;

  @override
  ConsumerState<PrayerReadScreen> createState() => _PrayerReadScreenState();
}

class _PrayerReadScreenState extends ConsumerState<PrayerReadScreen> {
  // Taken now: ref can't be used once the screen is closing, and the voice must stop then.
  late final _tts = ref.read(ttsProvider);
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  late bool _forSomeone = widget.forSomeone;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _tts.warmUp(ref.read(settingsProvider).language, male: _tts.prayerMale.value);
  }

  @override
  void dispose() {
    _tts.stop();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Praying for someone whose name hasn't been typed yet.
  bool _needsName(Prayer p) => _forSomeone && p.canPrayForSomeone && _name.text.trim().isEmpty;

  String _title(Prayer p) => _forSomeone && p.canPrayForSomeone ? p.forTitle ?? p.title : p.title;

  String _text(Prayer p, PrayerPassage? passage) =>
      passage?.text ?? (_forSomeone && p.canPrayForSomeone ? p.words(name: _name.text) : p.text) ?? '';

  /// Asks for the name first when it is needed; true when it is there.
  bool _ready(Prayer p) {
    if (!_needsName(p)) return true;
    _nameFocus.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).enterNameFirst),
        behavior: SnackBarBehavior.floating,
      ));
    return false;
  }

  void _play(Prayer p, PrayerPassage? passage) {
    if (!_ready(p)) return;
    readAloud(
      context,
      [_title(p), if (passage != null) passage.reference, _text(p, passage)],
      ref.read(settingsProvider).language,
      male: _tts.prayerMale.value,
    );
  }

  String _shareText(Prayer p, PrayerPassage? passage, AppLocalizations l) =>
      [_title(p), ?passage?.reference, _text(p, passage), '\n${shareFooter(l)}'].join('\n\n');

  Future<void> _whatsApp(Prayer p, PrayerPassage? passage, AppLocalizations l) async {
    if (!_ready(p)) return;
    final text = _shareText(p, passage, l);
    var sent = false;
    try {
      sent = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    // No WhatsApp: the share sheet has every other way to send it.
    if (!sent) await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _copy(Prayer p, PrayerPassage? passage, AppLocalizations l) async {
    if (!_ready(p)) return;
    await Clipboard.setData(ClipboardData(text: _shareText(p, passage, l)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.copied), behavior: SnackBarBehavior.floating));
  }

  void _picture(Prayer p, PrayerPassage? passage) {
    if (!_ready(p)) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.midnight,
      showDragHandle: true,
      builder: (_) => _PrayerPictureSheet(
        prayer: p,
        title: _title(p),
        reference: passage?.reference,
        text: _text(p, passage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prayer = ref
        .watch(prayerGroupsProvider)
        .value
        ?.expand((g) => g.prayers)
        .where((p) => p.id == widget.id)
        .firstOrNull;
    final passage = prayer?.passage == null ? null : ref.watch(prayerPassageProvider(prayer!.passage!));
    final ready = prayer != null && (passage == null || passage.hasValue);
    final words = passage?.value;

    // Tapping a prayer is asking to hear it: start once its words are here —
    // unless it is for someone whose name is still to be typed.
    if (ready && !_started && !_needsName(prayer)) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(prayer, words);
      });
    }

    final picture = prayer?.picture;
    final white = TextStyle(color: Colors.white.withValues(alpha: 0.85));
    return Scaffold(
      backgroundColor: AppColors.midnight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // His picture behind the whole prayer, darkened so every word stays easy to read.
          if (picture != null) Image.asset(picture.asset, fit: BoxFit.cover, alignment: picture.focus),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80060C1E), Color(0x99060C1E), Color(0xE6060C1E), Color(0xF2060C1E)],
                stops: [0, 0.3, 0.6, 1],
              ),
            ),
          ),
          if (!ready)
            const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
          else
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 60, 22, 40),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: Icon(prayer.icon, size: 30, color: AppColors.ember),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _title(prayer),
                    textAlign: TextAlign.center,
                    style: AppText.serif(30, color: Colors.white, weight: FontWeight.w600)
                        .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 10)]),
                  ),
                  if (words != null) ...[
                    const SizedBox(height: 4),
                    Text(words.reference,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600)),
                  ],
                  // Help from people first, for anyone who may be in danger.
                  if (prayer.crisis) ...[const SizedBox(height: 16), const CrisisCard()],
                  if (prayer.canPrayForSomeone) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: _ForWhomToggle(
                        dark: true,
                        forSomeone: _forSomeone,
                        onChanged: (v) {
                          _tts.stop();
                          setState(() => _forSomeone = v);
                          if (v && _name.text.trim().isEmpty) _nameFocus.requestFocus();
                        },
                      ),
                    ),
                    if (_forSomeone) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        focusNode: _nameFocus,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _play(prayer, words),
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          labelText: l.theirName,
                          hintText: l.theirNameHint,
                          labelStyle: white,
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.goldSoft),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.white38),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.goldSoft, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Center(child: VoiceToggle.prayers(dark: true, onChanged: () => _play(prayer, words))),
                  const SizedBox(height: 12),
                  PlaybackControls(dark: true, label: l.playPrayer, onPlay: () => _play(prayer, words)),
                  const SizedBox(height: 18),
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                    child: Column(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.goldSoft),
                        const SizedBox(height: 12),
                        Text(
                          _needsName(prayer) ? l.enterNameFirst : _text(prayer, words),
                          textAlign: TextAlign.center,
                          style: AppText.serif(20, height: 1.55, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(height: 50, child: WhatsAppStatusButton(onPressed: () => _picture(prayer, words))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Action(
                          icon: Icons.chat_rounded,
                          label: l.whatsappMessage,
                          onPressed: () => _whatsApp(prayer, words, l),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Action(
                          icon: Icons.share_rounded,
                          label: l.share,
                          onPressed: () {
                            if (_ready(prayer)) SharePlus.instance.share(ShareParams(text: _shareText(prayer, words, l)));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Action(icon: Icons.copy_rounded, label: l.copyText, onPressed: () => _copy(prayer, words, l)),
                      ),
                    ],
                  ),
                  if (words != null) ...[
                    const SizedBox(height: 20),
                    FutureBuilder(
                      future: ref.read(bibleProvider).attribution(ref.read(settingsProvider).lang),
                      builder: (_, snap) => Text(snap.data ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

/// The prayer as a full-screen (9:16) picture over its painting, to post as a
/// WhatsApp Status, save, or share — shown exactly as it will be sent.
class _PrayerPictureSheet extends StatefulWidget {
  const _PrayerPictureSheet({required this.prayer, required this.title, required this.text, this.reference});
  final Prayer prayer;
  final String title;
  final String? reference;
  final String text;

  @override
  State<_PrayerPictureSheet> createState() => _PrayerPictureSheetState();
}

class _PrayerPictureSheetState extends State<_PrayerPictureSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  Future<void> _send(Future<void> Function(Uint8List png, AppLocalizations l) action) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (widget.prayer.picture case final picture?) await precacheImage(AssetImage(picture.asset), context);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      await action(await PictureShare.render(boundary), l);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: RepaintBoundary(
                        key: _card,
                        child: PrayerPictureCard(
                          prayer: widget.prayer,
                          title: widget.title,
                          reference: widget.reference,
                          text: widget.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: StatusActions(
                  busy: _busy,
                  onWhatsApp: () => _send((png, l) => PictureShare.toWhatsApp(png, shareFooter(l))),
                  onSave: () => _send((png, l) async =>
                      _snack(await PictureShare.save(png, shareFooter(l)) ? l.pictureSaved : l.pictureSaveFailed)),
                  onShare: () => _send((png, l) => PictureShare.share(png, shareFooter(l))),
                ),
              ),
            ],
          ),
        ),
      );
}

/// A prayer on its painting of Jesus, sized as a status (360×640, shared at 1080 wide).
/// Long prayers get smaller type so every word fits; nothing is cut short.
class PrayerPictureCard extends StatelessWidget {
  const PrayerPictureCard({super.key, required this.prayer, required this.title, required this.text, this.reference});
  final Prayer prayer;
  final String title;
  final String? reference;
  final String text;

  static const size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    final picture = prayer.picture;
    final textSize = switch (text.length) {
      < 260 => 17.0,
      < 400 => 15.0,
      < 600 => 13.0,
      _ => 11.5,
    };
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 8)];
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.midnight),
          if (picture != null) Image.asset(picture.asset, fit: BoxFit.cover, alignment: picture.focus),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33060C1E), Color(0x80060C1E), Color(0xE6060C1E), Color(0xF5060C1E)],
                stops: [0, 0.25, 0.55, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 18),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: size.width - 48,
                        child: Column(
                          children: [
                            Icon(prayer.icon, color: AppColors.goldSoft, size: 26),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: AppText.serif(24, color: Colors.white, weight: FontWeight.w700, height: 1.15)
                                  .copyWith(shadows: shadow),
                            ),
                            if (reference != null) ...[
                              const SizedBox(height: 4),
                              Text(reference!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.goldSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              text,
                              textAlign: TextAlign.center,
                              style: AppText.serif(textSize, color: Colors.white, weight: FontWeight.w600, height: 1.4)
                                  .copyWith(shadows: shadow),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const StatusAppName(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
