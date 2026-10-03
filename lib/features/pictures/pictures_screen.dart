import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/picture_share.dart';
import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/painting.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Pictures of Jesus — every picture in the app, to save or share as a WhatsApp status.
class PicturesScreen extends ConsumerWidget {
  const PicturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final paintings = ref.watch(paintingsProvider).value;

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
                          Text(
                            l.picturesTitle,
                            textAlign: TextAlign.center,
                            style: AppText.serif(34, color: Colors.white),
                          ),
                          Text(
                            l.picturesSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    if (paintings == null)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: CircularProgressIndicator(color: AppColors.goldSoft)),
                        ),
                      )
                    else
                      SliverGrid.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 9 / 16,
                        children: [
                          for (final (i, p) in paintings.indexed)
                            Material(
                              color: AppColors.navy,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.18)),
                              ),
                              child: Ink.image(
                                image: ResizeImage(AssetImage(p.asset), width: 300),
                                fit: BoxFit.cover,
                                alignment: p.focus,
                                child: InkWell(onTap: () => context.push('/pictures/$i')),
                              ),
                            ),
                        ],
                      ),
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
/// a full-screen (9:16) status with a verse and the app's name.
class PictureViewerScreen extends ConsumerStatefulWidget {
  const PictureViewerScreen({super.key, required this.index});
  final int index;

  @override
  ConsumerState<PictureViewerScreen> createState() => _PictureViewerScreenState();
}

class _PictureViewerScreenState extends ConsumerState<PictureViewerScreen> {
  late final _pages = PageController(initialPage: widget.index, viewportFraction: 0.86);
  late int _page = widget.index;
  final _cards = <int, GlobalKey>{};
  bool _showVerse = true;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int i) => _cards.putIfAbsent(i, GlobalKey.new);

  /// Renders the current card, waiting for its picture first so it is never blank.
  Future<void> _send(Future<void> Function(Uint8List png, AppLocalizations l) action) async {
    final painting = ref.read(paintingsProvider).value?[_page];
    if (_busy || painting == null) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await precacheImage(AssetImage(painting.asset), context);
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
    final paintings = ref.watch(paintingsProvider).value;

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: paintings == null
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
                          '${_page + 1} / ${paintings.length}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const Spacer(),
                        // Verse on or off — a clean picture still carries the app's name.
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(l.verseOnPicture),
                            selected: _showVerse,
                            onSelected: (v) => setState(() => _showVerse = v),
                            showCheckmark: true,
                            checkmarkColor: AppColors.midnight,
                            selectedColor: AppColors.goldSoft,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            labelStyle: TextStyle(color: _showVerse ? AppColors.midnight : Colors.white),
                            side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.4)),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: paintings.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Center(
                            child: FittedBox(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: RepaintBoundary(
                                  key: _keyFor(i),
                                  child: PictureCard(
                                    painting: paintings[i],
                                    verse: _showVerse ? ref.watch(pictureVerseProvider(i)).value : null,
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
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _send((png, l) => PictureShare.toWhatsApp(png, shareFooter(l))),
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.motion_photos_on_rounded),
                              label: Text(
                                l.whatsappStatus,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _OutlineAction(
                                  icon: Icons.download_rounded,
                                  label: l.savePicture,
                                  onPressed: _busy
                                      ? null
                                      : () => _send(
                                          (png, l) async => _snack(
                                            await PictureShare.save(png, shareFooter(l)) ? l.pictureSaved : l.pictureSaveFailed,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _OutlineAction(
                                  icon: Icons.share_rounded,
                                  label: l.share,
                                  onPressed: _busy
                                      ? null
                                      : () => _send((png, l) => PictureShare.share(png, shareFooter(l))),
                                ),
                              ),
                            ],
                          ),
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
  const PictureCard({super.key, required this.painting, this.verse});
  final Painting painting;
  final Verse? verse;

  static const size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final verse = this.verse;
    // Long verses get smaller type so every word fits — Scripture is never cut short.
    final verseSize = switch (verse?.text.length ?? 0) {
      < 90 => 21.0,
      < 160 => 18.0,
      < 240 => 15.5,
      _ => 13.5,
    };

    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.midnight),
          Image.asset(painting.asset, fit: BoxFit.cover, alignment: painting.focus),
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
            child: Column(
              children: [
                if (verse != null) ...[
                  Text(
                    '“${verse.text}”',
                    textAlign: TextAlign.center,
                    style: AppText.serif(
                      verseSize,
                      color: Colors.white,
                      weight: FontWeight.w600,
                      height: 1.3,
                    ).copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${verse.reference} · ${verse.translation}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.goldSoft, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
