import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/picture_share.dart';
import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// A picture as it can be shared as a status.
class StatusPicture {
  const StatusPicture({
    required this.asset,
    this.focus = Alignment.center,
    this.wide = false,
    this.caption,
    this.title,
    this.verse,
  });

  final String asset;

  /// What to keep in frame when cover-cropping.
  final Alignment focus;

  /// Art not made for a 9:16 status — Bible Stories and books, whose titles are
  /// painted in — is shown whole over a blurred copy of itself, never cropped.
  final bool wide;

  /// A small gold line above [title], e.g. "Bible Stories".
  final String? caption;

  /// The story's or book's name in the reader's language.
  final String? title;

  /// The verse to carry on the picture, if it has one.
  final Future<Verse?> Function()? verse;
}

/// The pictures of one collection, in order: the paintings of Jesus, the
/// Bible Stories, or the books of the Bible. Null while loading.
List<StatusPicture>? statusPictures(WidgetRef ref, BuildContext context, String collection) {
  final l = AppLocalizations.of(context);
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  final bible = ref.watch(bibleProvider);
  switch (collection) {
    case 'stories':
      return [
        for (final s in ref.watch(storiesProvider).value ?? const [])
          StatusPicture(asset: s.image.asset, focus: s.image.focus, wide: true, caption: l.bibleStories, title: s.title(lang)),
      ].nullIfEmpty;
    case 'books':
      return [
        for (final b in ref.watch(bibleBooksProvider).value ?? const [])
          if (b.picture case final picture?)
            StatusPicture(
              asset: picture,
              wide: true,
              caption: l.holyBible,
              title: b.name,
              verse: () => bible.keyVerse(b, lang),
            ),
      ].nullIfEmpty;
    default:
      return [
        for (final (i, p) in (ref.watch(paintingsProvider).value ?? const []).indexed)
          StatusPicture(asset: p.asset, focus: p.focus, verse: () => ref.read(pictureVerseProvider(i).future)),
      ].nullIfEmpty;
  }
}

extension on List<StatusPicture> {
  List<StatusPicture>? get nullIfEmpty => isEmpty ? null : this;
}

/// Every picture in the app — of Jesus, of the Bible Stories, of the books of
/// the Bible — to save or share as a WhatsApp status.
class PicturesScreen extends ConsumerWidget {
  const PicturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    List<Widget> section(String label, String collection, int columns, double aspect) {
      final pictures = statusPictures(ref, context, collection);
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
            child: Text(label,
                style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          ),
        ),
        if (pictures == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: AppColors.goldSoft)),
            ),
          )
        else
          SliverGrid.count(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: aspect,
            children: [
              for (final (i, p) in pictures.indexed)
                Material(
                  color: AppColors.navy,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.18)),
                  ),
                  child: Ink.image(
                    image: ResizeImage(AssetImage(p.asset), width: 360),
                    fit: BoxFit.cover,
                    alignment: p.focus,
                    child: InkWell(onTap: () => context.push('/pictures/$collection/$i')),
                  ),
                ),
            ],
          ),
      ];
    }

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                            ),
                          ),
                          Text(l.pictures, textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white)),
                          Text(
                            l.picturesSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ],
                      ),
                    ),
                    ...section(l.picturesTitle, 'jesus', 3, 9 / 16),
                    ...section(l.bibleStories, 'stories', 2, 1),
                    ...section(l.booksOfTheBible, 'books', 2, 3 / 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One picture at a time, swipe for the next, shown exactly as it will be shared:
/// a full-screen (9:16) status with its verse and the app's name.
class PictureViewerScreen extends ConsumerStatefulWidget {
  const PictureViewerScreen({super.key, this.collection = 'jesus', required this.index});

  /// 'jesus', 'stories' or 'books' — see [statusPictures].
  final String collection;
  final int index;

  @override
  ConsumerState<PictureViewerScreen> createState() => _PictureViewerScreenState();
}

class _PictureViewerScreenState extends ConsumerState<PictureViewerScreen> {
  late final _pages = PageController(initialPage: widget.index, viewportFraction: 0.86);
  late int _page = widget.index;
  final _cards = <int, GlobalKey>{};
  final _verses = <int, Future<Verse?>>{};
  bool _showVerse = true;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int i) => _cards.putIfAbsent(i, GlobalKey.new);

  Future<Verse?>? _verseFor(List<StatusPicture> pictures, int i) =>
      pictures[i].verse == null ? null : _verses.putIfAbsent(i, pictures[i].verse!);

  /// Renders the current card, waiting for its picture first so it is never blank.
  Future<void> _send(StatusPicture? picture, Future<void> Function(Uint8List png, AppLocalizations l) action) async {
    if (_busy || picture == null) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await precacheImage(AssetImage(picture.asset), context);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _keyFor(_page).currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pictures = statusPictures(ref, context, widget.collection);
    final current = pictures?.elementAtOrNull(_page);

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: pictures == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
              : Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => context.canPop() ? context.pop() : context.go('/pictures'),
                        ),
                        const Spacer(),
                        Text(
                          '${_page + 1} / ${pictures.length}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const Spacer(),
                        // Verse on or off — a clean picture still carries the app's name.
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Visibility.maintain(
                            visible: current?.verse != null,
                            child: FilterChip(
                              label: Text(l.verseOnPicture),
                              selected: _showVerse,
                              onSelected: (v) => setState(() => _showVerse = v),
                              showCheckmark: true,
                              checkmarkColor: AppColors.midnight,
                              color: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.selected)
                                    ? AppColors.goldSoft
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                              labelStyle: TextStyle(color: _showVerse ? AppColors.midnight : Colors.white),
                              side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: pictures.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Center(
                            child: FittedBox(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: RepaintBoundary(
                                  key: _keyFor(i),
                                  child: FutureBuilder(
                                    future: _showVerse ? _verseFor(pictures, i) : null,
                                    builder: (_, snap) => PictureCard(
                                      picture: pictures[i],
                                      verse: _showVerse ? snap.data : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: StatusActions(
                        busy: _busy,
                        onWhatsApp: () => _send(current, (png, l) => PictureShare.toWhatsApp(png, shareFooter(l))),
                        onSave: () => _send(
                          current,
                          (png, l) async =>
                              _snack(await PictureShare.save(png, shareFooter(l)) ? l.pictureSaved : l.pictureSaveFailed),
                        ),
                        onShare: () => _send(current, (png, l) => PictureShare.share(png, shareFooter(l))),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// WhatsApp Status first and largest, then Save and Share.
class StatusActions extends StatelessWidget {
  const StatusActions({
    super.key,
    required this.busy,
    required this.onWhatsApp,
    required this.onSave,
    required this.onShare,
  });
  final bool busy;
  final VoidCallback onWhatsApp;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: WhatsAppStatusButton(busy: busy, onPressed: onWhatsApp),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _OutlineAction(icon: Icons.download_rounded, label: l.savePicture, onPressed: busy ? null : onSave)),
            const SizedBox(width: 10),
            Expanded(child: _OutlineAction(icon: Icons.share_rounded, label: l.share, onPressed: busy ? null : onShare)),
          ],
        ),
      ],
    );
  }
}

/// The green WhatsApp Status button.
class WhatsAppStatusButton extends StatelessWidget {
  const WhatsAppStatusButton({super.key, this.busy = false, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
    ),
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : const Icon(Icons.motion_photos_on_rounded),
    label: Text(
      AppLocalizations.of(context).whatsappStatus,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );
}

/// The picture as it is shared: 360×640 logical pixels (rendered at 1080×1920),
/// the verse over a dark fade, and the app's name at the foot so anyone who sees it can find the app.
class PictureCard extends StatelessWidget {
  const PictureCard({super.key, required this.picture, this.verse});
  final StatusPicture picture;
  final Verse? verse;

  static const size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    final verse = this.verse;
    final wide = picture.wide;
    // Long verses get smaller type so every word fits — Scripture is never cut short.
    final verseSize = switch (verse?.text.length ?? 0) {
      < 90 => 21.0,
      < 160 => 18.0,
      < 240 => 15.5,
      _ => 13.5,
    };

    final words = [
      if (picture.caption case final caption?)
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.goldSoft, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
        ),
      if (picture.title case final title?) ...[
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppText.serif(verse == null ? 30 : 24, color: Colors.white, weight: FontWeight.w700, height: 1.15)
              .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)]),
        ),
        if (verse != null) const SizedBox(height: 12),
      ],
      if (verse != null) ...[
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '“'),
            redLetterSpan(verse.text, verse.jesusWords),
            const TextSpan(text: '”'),
          ]),
          textAlign: TextAlign.center,
          style: AppText.serif(verseSize, color: Colors.white, weight: FontWeight.w600, height: 1.3)
              .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)]),
        ),
        const SizedBox(height: 8),
        Text(
          '${verse.reference} · ${verse.translation}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.goldSoft, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ];
    const appName = StatusAppName();

    if (wide) {
      // A blurred copy fills the card; the picture sits whole at the top, and the
      // words fill the space beneath it — shrinking if they must, never covering it.
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.midnight),
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp),
              child: Image.asset(picture.asset, fit: BoxFit.cover),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66060C1E), Color(0xE6060C1E)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 30, 14, 18),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(picture.asset, fit: BoxFit.contain),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(width: size.width - 52, child: Column(children: words)),
                        ),
                      ),
                    ),
                  ),
                  appName,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.midnight),
          Image.asset(picture.asset, fit: BoxFit.cover, alignment: picture.focus),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: verse == null
                    ? const [Color(0x00060C1E), Color(0x00060C1E), Color(0xB3060C1E)]
                    : const [Color(0x00060C1E), Color(0x1A060C1E), Color(0xE6060C1E), Color(0xF2060C1E)],
                stops: verse == null ? const [0, 0.78, 1] : const [0, 0.38, 0.72, 1],
              ),
            ),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 18,
            child: Column(children: [...words, if (verse != null) const SizedBox(height: 16), appName]),
          ),
        ],
      ),
    );
  }
}

/// The app's mark, name, tagline and "Get it on Google Play" along the foot of a shared picture.
class StatusAppName extends StatelessWidget {
  const StatusAppName({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const LogoMark(size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 17),
              Text(
                l.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9.5),
              ),
              // A saved or forwarded picture carries no link, so it says where to find the app.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 11, color: AppColors.goldSoft),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      l.getItOnGooglePlay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.goldSoft, fontSize: 9.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
