import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/night_background.dart';
import '../../data/bible/bible_repository.dart';
import '../../data/models/painting.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../bible/bible_screen.dart';

/// Words of Jesus — the four Gospels whole, and every other chapter in which
/// He speaks, with His words in red. Pick a book, then a chapter.
class JesusWordsScreen extends ConsumerWidget {
  const JesusWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final books = ref.watch(jesusBooksProvider).value;
    final paintings = ref.watch(paintingsProvider).value;
    final painting = ref.watch(dailyPaintingProvider).value;

    return Scaffold(
      body: NightBackground(
        light: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            PaintingHero(
              painting: painting,
              height: MediaQuery.sizeOf(context).height * 0.42,
              onBack: () => context.canPop() ? context.pop() : context.go('/home'),
              child: Column(
                children: [
                  Text(l.wordsOfJesus,
                      textAlign: TextAlign.center,
                      style: AppText.serif(34, color: Colors.white, weight: FontWeight.w600, height: 1.15)),
                  const SizedBox(height: 4),
                  Text(l.wordsOfJesusSubtitle,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.redLetter, fontSize: 15)),
                ],
              ),
            ),
            if (books == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.goldSoft)),
              )
            else
              for (final b in books) _BookSection(book: b, painting: paintingFor(paintings, b.code, 0)),
          ],
        ),
      ),
    );
  }
}

/// A book's picture card, then its chapters as numbers to tap.
class _BookSection extends StatelessWidget {
  const _BookSection({required this.book, required this.painting});
  final BibleBook book;
  final Painting? painting;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (painting case final p?)
                      Image.asset(p.asset, fit: BoxFit.cover, alignment: p.focus, cacheWidth: 600)
                    else
                      const ColoredBox(color: AppColors.navyLight),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xE6060C1E), Color(0x33060C1E)]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(book.name, style: AppText.serif(28, color: Colors.white, weight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ChapterNumbers(
              chapters: book.chapters,
              onTap: (c) => context.push('/bible/${book.code}/$c?words=1'),
            ),
          ],
        ),
      );
}
