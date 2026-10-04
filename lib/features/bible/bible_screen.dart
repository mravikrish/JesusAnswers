import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/divine_light.dart';
import '../../core/widgets/night_background.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/bible/bible_repository.dart';
import '../../data/models/painting.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../pictures/pictures_screen.dart';

/// Where the reader last was, e.g. "GEN 3", for Continue reading.
const _lastReadKey = 'bible.lastRead';

/// A painting of Jesus for [book] [chapter] — the same one each visit,
/// different from chapter to chapter.
Painting? paintingFor(List<Painting>? paintings, String book, int chapter, [int offset = 0]) {
  if (paintings == null || paintings.isEmpty) return null;
  final seed = book.codeUnits.fold(0, (a, c) => a * 31 + c) + chapter * 7 + offset;
  return paintings[seed % paintings.length];
}

/// The Holy Bible — all 66 books. Pick a book, then a chapter; or carry on
/// from the chapter last read.
class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final books = ref.watch(bibleBooksProvider).value;
    final paintings = ref.watch(paintingsProvider).value;
    final last = ref.watch(prefsProvider).getString(_lastReadKey)?.split(' ');
    final lastBook = last == null ? null : books?.where((b) => b.code == last.first).firstOrNull;
    final lastChapter = last == null || last.length < 2 ? null : int.tryParse(last[1]);

    List<Widget> section(String label, Iterable<BibleBook> list) => [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
            child: Text(label,
                style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
            children: [for (final b in list) _BookTile(book: b)],
          ),
        ];

    return Scaffold(
      body: NightBackground(
        light: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            PaintingHero(
              painting: paintingFor(paintings, 'BIBLE', 0),
              height: MediaQuery.sizeOf(context).height * 0.36,
              onBack: () => context.canPop() ? context.pop() : context.go('/home'),
              child: Column(
                children: [
                  Text(l.holyBible,
                      textAlign: TextAlign.center,
                      style: AppText.serif(34, color: Colors.white, weight: FontWeight.w600, height: 1.15)),
                  const SizedBox(height: 4),
                  Text(l.holyBibleSubtitle,
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: books == null
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.goldSoft)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (lastBook != null && lastChapter != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.icon(
                              onPressed: () => context.push('/bible/${lastBook.code}/$lastChapter'),
                              icon: const Icon(Icons.bookmark_rounded),
                              label: Text('${l.continueReading} · ${lastBook.name} $lastChapter'),
                            ),
                          ),
                        ...section(l.oldTestament, books.where((b) => b.oldTestament)),
                        ...section(l.newTestament, books.where((b) => !b.oldTestament)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A book's picture with its name; tap for its key verse and chapters.
class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book});
  final BibleBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
        color: AppColors.navy,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.navy,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => _BookSheet(book: book, parent: context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 3 / 2, child: BookPicture(book: book, cacheWidth: 400)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Text(
                      book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.serif(17, color: Colors.white, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// A book's picture, its key verse to draw the reader in, and its chapters.
class _BookSheet extends ConsumerWidget {
  const _BookSheet({required this.book, required this.parent});
  final BibleBook book;

  /// The Bible screen's context, still mounted after the sheet closes.
  final BuildContext parent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    void open(int chapter) {
      Navigator.pop(context);
      parent.push('/bible/${book.code}/$chapter');
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookPicture(book: book),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00060C1E), Color(0x00060C1E), AppColors.navy],
                        stops: [0, 0.6, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 8,
                    child: Text(book.name, style: AppText.serif(30, color: Colors.white, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder(
                    future: ref.read(bibleProvider).keyVerse(book, lang),
                    builder: (_, snap) => snap.data == null
                        ? const SizedBox(height: 8)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: VerseQuote(verse: snap.data!, dark: true, size: 19),
                          ),
                  ),
                  if (book.picture != null) ...[
                    SizedBox(
                      height: 46,
                      child: WhatsAppStatusButton(
                        onPressed: () async {
                          final books = await ref.read(bibleBooksProvider.future);
                          if (!context.mounted) return;
                          final index = books.where((b) => b.picture != null).toList().indexWhere((b) => b.code == book.code);
                          Navigator.pop(context);
                          parent.push('/pictures/books/$index');
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (book.chapters.length == 1)
                    FilledButton.icon(
                      onPressed: () => open(1),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(AppLocalizations.of(context).readChapter),
                    )
                  else
                    ChapterNumbers(chapters: book.chapters, onTap: open),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [book]'s picture, cover-cropped; a painting of Jesus until it has one.
class BookPicture extends ConsumerWidget {
  const BookPicture({super.key, required this.book, this.cacheWidth});
  final BibleBook book;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painting = book.picture == null ? paintingFor(ref.watch(paintingsProvider).value, book.code, 0) : null;
    final asset = book.picture ?? painting?.asset;
    if (asset == null) return const ColoredBox(color: AppColors.navyLight);
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: painting?.focus ?? Alignment.center,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.navyLight),
    );
  }
}

/// A book's chapters as round numbers to tap.
class ChapterNumbers extends StatelessWidget {
  const ChapterNumbers({super.key, required this.chapters, required this.onTap});
  final List<int> chapters;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in chapters)
            SizedBox.square(
              dimension: 46,
              child: Material(
                color: Colors.white.withValues(alpha: 0.07),
                shape: CircleBorder(side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.25))),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onTap(c),
                  child: Center(child: Text('$c', style: const TextStyle(color: Colors.white, fontSize: 15))),
                ),
              ),
            ),
        ],
      );
}

/// One chapter: a painting of Jesus, then verse by verse with His words in
/// red, a painting between every few verses, and Listen. "Only His words"
/// dims everything He didn't say and reads aloud only what He said.
///
/// [words] opens it from Words of Jesus: previous/next stay within those
/// chapters, and outside the Gospels only the verses He speaks in are shown.
/// [highlight] is a verse to scroll to and mark, e.g. from Read the whole chapter.
class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key, required this.book, required this.chapter, this.words = false, this.highlight});
  final String book;
  final int chapter;
  final bool words;
  final int? highlight;

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  late final _tts = ref.read(ttsProvider);
  bool? _onlyHisChoice;
  final _highlightKey = GlobalKey();
  var _scrolled = false;

  /// A painting after every this many verses.
  static const _versesPerPicture = 12;

  /// Outside the Gospels, Words of Jesus shows only the verses He speaks in.
  bool get _onlyHisFixed => widget.words && !BibleRepository.gospels.contains(widget.book);

  @override
  void initState() {
    super.initState();
    if (!widget.words) ref.read(prefsProvider).setString(_lastReadKey, '${widget.book} ${widget.chapter}');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// The chapter before (-1) or after (+1) this one, across books.
  (BibleBook, int)? _neighbour(List<BibleBook> books, int step) {
    final bi = books.indexWhere((b) => b.code == widget.book);
    if (bi < 0) return null;
    final ci = books[bi].chapters.indexOf(widget.chapter) + step;
    if (ci >= 0 && ci < books[bi].chapters.length) return (books[bi], books[bi].chapters[ci]);
    final nb = bi + step;
    if (nb < 0 || nb >= books.length) return null;
    return (books[nb], step > 0 ? books[nb].chapters.first : books[nb].chapters.last);
  }

  void _scrollToHighlight() {
    if (_scrolled || widget.highlight == null) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 0.3, duration: const Duration(milliseconds: 500));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final books = ref.watch(widget.words ? jesusBooksProvider : bibleBooksProvider).value;
    final book = books?.where((b) => b.code == widget.book).firstOrNull;
    final verses = ref.watch(chapterProvider((widget.book, widget.chapter))).value;
    final paintings = ref.watch(paintingsProvider).value;
    final title = '${book?.name ?? widget.book} ${widget.chapter}';
    final hasHisWords = verses?.any((v) => v.jesusWords.isNotEmpty) ?? false;
    final onlyHis = _onlyHisFixed || (_onlyHisChoice ?? false);

    final shown = [
      for (final v in verses ?? const <NumberedVerse>[])
        if (!onlyHis || v.jesusWords.isNotEmpty) v,
    ];

    final body = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      if (i > 0 && i % _versesPerPicture == 0) {
        body.add(_PictureBreak(painting: paintingFor(paintings, widget.book, widget.chapter, i)));
      }
      final v = shown[i];
      final marked = v.number == widget.highlight;
      body.add(_VerseLine(
        key: marked ? _highlightKey : null,
        verse: v,
        marked: marked,
        dimNarration: onlyHis && !_onlyHisFixed,
        onLongPress: () async {
          final translation = await ref.read(bibleProvider).translation(settings.lang);
          if (!context.mounted) return;
          showVerseActions(
            context,
            Verse(
              ref: '${widget.book} ${widget.chapter}:${v.number}',
              reference: '$title:${v.number}',
              text: v.text,
              translation: translation,
              lang: settings.lang,
              jesusWords: v.jesusWords,
            ),
            readChapter: false,
          );
        },
      ));
    }
    if (verses != null) _scrollToHighlight();

    final previous = books == null ? null : _neighbour(books, -1);
    final next = books == null ? null : _neighbour(books, 1);
    void go((BibleBook, int) to) =>
        context.pushReplacement('/bible/${to.$1.code}/${to.$2}${widget.words ? '?words=1' : ''}');

    return Scaffold(
      body: NightBackground(
        warm: true,
        light: false,
        child: verses == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaintingHero(
                      painting: paintingFor(paintings, widget.book, widget.chapter),
                      height: MediaQuery.sizeOf(context).height * 0.42,
                      onBack: () => context.canPop() ? context.pop() : context.go(widget.words ? '/jesus' : '/bible'),
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: AppText.serif(34, color: Colors.white, weight: FontWeight.w600, height: 1.15)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasHisWords && !_onlyHisFixed)
                            Center(
                              child: FilterChip(
                                label: Text(l.onlyHisWords),
                                selected: onlyHis,
                                onSelected: (on) => setState(() => _onlyHisChoice = on),
                                avatar: const Icon(Icons.format_quote_rounded, color: AppColors.redLetter, size: 18),
                                showCheckmark: false,
                                labelStyle: TextStyle(color: onlyHis ? AppColors.midnight : Colors.white),
                                backgroundColor: Colors.white.withValues(alpha: 0.07),
                                selectedColor: AppColors.redLetter,
                                side: BorderSide(color: AppColors.redLetter.withValues(alpha: 0.5)),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          const SizedBox(height: 10),
                          PlaybackControls(
                            dark: true,
                            label: l.listen,
                            onPlay: () => readAloud(
                              context,
                              [title, for (final v in shown) onlyHis ? v.spoken : v.text],
                              settings.language,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...body,
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (previous != null)
                                Flexible(
                                  child: TextButton.icon(
                                    onPressed: () => go(previous),
                                    icon: const Icon(Icons.chevron_left_rounded),
                                    label: Text('${previous.$1.name} ${previous.$2}', overflow: TextOverflow.ellipsis),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.goldSoft),
                                  ),
                                ),
                              const Spacer(),
                              if (next != null)
                                Flexible(
                                  child: TextButton.icon(
                                    onPressed: () => go(next),
                                    iconAlignment: IconAlignment.end,
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    label: Text('${next.$1.name} ${next.$2}', overflow: TextOverflow.ellipsis),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.goldSoft),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder(
                            future: ref.read(bibleProvider).attribution(settings.lang),
                            builder: (_, snap) => Text(
                              snap.data ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            ),
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

/// A verse with its number; long-press to copy or share it.
class _VerseLine extends StatelessWidget {
  const _VerseLine({
    super.key,
    required this.verse,
    required this.marked,
    required this.dimNarration,
    required this.onLongPress,
  });
  final NumberedVerse verse;
  final bool marked;
  final bool dimNarration;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(vertical: 3, horizontal: marked ? 8 : 0),
          decoration: marked
              ? BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${verse.number}  ',
                style: const TextStyle(color: AppColors.goldSoft, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              redLetterSpan(verse.text, verse.jesusWords),
            ]),
            style: AppText.serif(21, color: Colors.white.withValues(alpha: dimNarration ? 0.45 : 1), height: 1.5),
          ),
        ),
      );
}

/// A painting of Jesus between verses.
class _PictureBreak extends StatelessWidget {
  const _PictureBreak({required this.painting});
  final Painting? painting;

  @override
  Widget build(BuildContext context) {
    final p = painting;
    if (p == null) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.asset(p.asset, fit: BoxFit.cover, alignment: p.focus, cacheWidth: 900),
        ),
      ),
    );
  }
}

/// A painting fading into the night sky, with back over it and [child] below.
class PaintingHero extends StatelessWidget {
  const PaintingHero({
    super.key,
    required this.painting,
    required this.height,
    required this.onBack,
    required this.child,
  });
  final Painting? painting;
  final double height;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (painting case final p?) Image.asset(p.asset, fit: BoxFit.cover, alignment: p.focus),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99060C1E), Color(0x00060C1E), Color(0x330A1430), Color(0xE60A1430), AppColors.midnight],
                stops: [0, 0.22, 0.5, 0.82, 1],
              ),
            ),
          ),
          const IgnorePointer(child: DivineLight(intensity: 0.5)),
          Positioned(
            top: top + 4,
            left: 8,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: onBack,
            ),
          ),
          Positioned(left: 22, right: 22, bottom: 14, child: child),
        ],
      ),
    );
  }
}
