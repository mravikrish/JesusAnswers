import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/night_background.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/models/story.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Bible Stories — well-loved stories, Old Testament then New.
class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final stories = ref.watch(storiesProvider).value;

    Widget section(String label, Iterable<Story> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(label,
                  style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            ),
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StoryTile(story: s, lang: lang),
              ),
          ],
        );

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                ),
              ),
              Text(l.bibleStories, textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white)),
              Text(l.bibleStoriesSubtitle,
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
              if (stories == null)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.goldSoft)),
                )
              else ...[
                section(l.oldTestament, stories.where((s) => s.oldTestament)),
                section(l.newTestament, stories.where((s) => !s.oldTestament)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.lang});
  final Story story;
  final String lang;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/stories/${story.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                _StoryIcon(icon: story.icon, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(story.title(lang),
                      style: AppText.serif(21, color: Colors.white, weight: FontWeight.w600, height: 1.2)),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      );
}

class _StoryIcon extends StatelessWidget {
  const _StoryIcon({required this.icon, required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppColors.gold.withValues(alpha: 0.45),
            AppColors.gold.withValues(alpha: 0.08),
          ]),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      );
}

/// One story, read like a short chapter: each passage with its verse numbers,
/// and Listen to hear the whole story.
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
        child: SafeArea(
          bottom: false,
          child: story == null || passages == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 48),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/stories'),
                      ),
                    ),
                    Center(child: _StoryIcon(icon: story.icon, size: 64)),
                    const SizedBox(height: 12),
                    Text(story.title(settings.lang),
                        textAlign: TextAlign.center,
                        style: AppText.serif(34, color: Colors.white, weight: FontWeight.w600, height: 1.15)),
                    const SizedBox(height: 6),
                    Text(
                      passages.map((p) => p.reference).join(' · '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.goldSoft, fontSize: 13, fontWeight: FontWeight.w600),
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
