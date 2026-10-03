import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/divine_light.dart';
import '../../core/widgets/night_background.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/models/story.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Bible Stories — well-loved stories as picture cards, Old Testament then New.
class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final stories = ref.watch(storiesProvider).value;

    List<Widget> section(String label, Iterable<Story> list) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
              child: Text(label,
                  style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            ),
          ),
          SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: [for (final s in list) _StoryCard(story: s, lang: lang)],
          ),
        ];

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
                          Text(l.bibleStories,
                              textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white)),
                          Text(l.bibleStoriesSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                    if (stories == null)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: CircularProgressIndicator(color: AppColors.goldSoft)),
                        ),
                      )
                    else ...[
                      ...section(l.oldTestament, stories.where((s) => s.oldTestament)),
                      ...section(l.newTestament, stories.where((s) => !s.oldTestament)),
                    ],
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

/// The story's picture with its title over a dark fade.
class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.lang});
  final Story story;
  final String lang;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.navy,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          onTap: () => context.push('/stories/${story.id}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Picture(story: story, cacheWidth: 400),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00060C1E), Color(0x00060C1E), Color(0xE6060C1E)],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  story.title(lang),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(20, color: Colors.white, weight: FontWeight.w600, height: 1.15),
                ),
              ),
            ],
          ),
        ),
      );
}

/// The story's picture, cover-cropped around its focus; the story's icon if it is missing.
class _Picture extends StatelessWidget {
  const _Picture({required this.story, this.cacheWidth});
  final Story story;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
        story.image.asset,
        fit: BoxFit.cover,
        alignment: story.image.focus,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.navyLight,
          child: Icon(story.icon, color: AppColors.goldSoft, size: 48),
        ),
      );
}

/// One story, read like a short chapter: its picture, then each passage with
/// verse numbers, and Listen to hear the whole story.
class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  late final _tts = ref.read(ttsProvider);

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final story = ref.watch(storiesProvider).value?.where((s) => s.id == widget.id).firstOrNull;
    final passages = story == null ? null : ref.watch(storyPassagesProvider(story)).value;

    return Scaffold(
      body: NightBackground(
        warm: true,
        light: false,
        child: story == null || passages == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
            : ListView(
                padding: const EdgeInsets.only(bottom: 48),
                children: [
                  _Hero(story: story, height: MediaQuery.sizeOf(context).height * 0.45),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(story.title(settings.lang),
                            textAlign: TextAlign.center,
                            style: AppText.serif(34, color: Colors.white, weight: FontWeight.w600, height: 1.15)),
                        const SizedBox(height: 6),
                        Text(
                          passages.map((p) => p.reference).join(' · '),
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppColors.goldSoft, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 18),
                        PlaybackControls(
                          dark: true,
                          label: l.listen,
                          onPlay: () => readAloud(
                            context,
                            [
                              story.title(settings.lang),
                              for (final p in passages) ...[p.reference, for (final (_, text) in p.verses) text],
                            ],
                            settings.language,
                          ),
                        ),
                        for (final p in passages) _Passage(passage: p),
                        const SizedBox(height: 28),
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
    );
  }
}

/// The story's picture, fading into the night sky, with back over it.
class _Hero extends StatelessWidget {
  const _Hero({required this.story, required this.height});
  final Story story;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Picture(story: story),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99060C1E), Color(0x00060C1E), Color(0x330A1430), Color(0xE60A1430), AppColors.midnight],
                stops: [0, 0.22, 0.55, 0.85, 1],
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
              onPressed: () => context.canPop() ? context.pop() : context.go('/stories'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Passage extends StatelessWidget {
  const _Passage({required this.passage});
  final StoryPassage passage;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(passage.reference,
                style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                for (final (n, text) in passage.verses) ...[
                  TextSpan(
                    text: '$n ',
                    style: const TextStyle(color: AppColors.goldSoft, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '$text '),
                ],
              ]),
              style: AppText.serif(22, color: Colors.white, height: 1.5),
            ),
          ],
        ),
      );
}
