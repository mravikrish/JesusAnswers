import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/divine_light.dart';
import '../../data/models/answer.dart';
import '../../data/models/mood.dart';
import '../../data/models/topic.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

enum _Filter { all, questions, prayers, favorites }

/// My Journey — a record of questions, Scriptures and prayers over time.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  _Filter _filter = _Filter.all;
  Topic? _topic;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Matches what was asked, the reply, the prayer and the verses.
  static bool _contains(Answer a, String query) => [
        a.question,
        a.encouragement,
        a.prayer,
        for (final v in a.verses) ...[v.reference, v.text],
      ].any((t) => t.toLowerCase().contains(query));

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool dark = true}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: dark ? AppColors.navy : AppColors.goldSoft,
          labelStyle: TextStyle(color: selected && dark ? Colors.white : AppColors.ink),
          shape: const StadiumBorder(side: BorderSide(color: AppColors.sand)),
          onSelected: (_) => onTap(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final all = ref.watch(journeyProvider);
    final query = _search.text.trim().toLowerCase();
    // Only topics that something in the journey is about; the row shows when there's a choice.
    final topics = [for (final t in Topic.values) if (all.any(t.matches)) t];
    final topic = topics.length > 1 && topics.contains(_topic) ? _topic : null;
    final entries = all
        .where(
          (a) => switch (_filter) {
            _Filter.all => true,
            _Filter.questions => a.kind == AnswerKind.question,
            _Filter.prayers => a.kind == AnswerKind.prayer,
            _Filter.favorites => a.favorite,
          },
        )
        .where((a) => topic?.matches(a) ?? true)
        .where((a) => query.isEmpty || _contains(a, query))
        .toList();
    final labels = {
      _Filter.all: l.filterAll,
      _Filter.questions: l.filterQuestions,
      _Filter.prayers: l.filterPrayers,
      _Filter.favorites: l.filterFavorites,
    };

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: DivineLight(color: AppColors.gold, intensity: 0.35)),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(child: Text(l.journeyTitle, style: AppText.serif(34, weight: FontWeight.w600))),
                        if (all.isNotEmpty)
                          IconButton(
                            tooltip: l.searchJourney,
                            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                            onPressed: () => setState(() {
                              _searching = !_searching;
                              if (!_searching) _search.clear();
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_searching)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: TextField(
                        controller: _search,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l.searchJourney,
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppColors.sand),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        for (final f in _Filter.values)
                          _chip(labels[f]!, _filter == f, () => setState(() => _filter = f)),
                      ],
                    ),
                  ),
                ),
                if (topics.length > 1)
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Row(
                        children: [
                          for (final t in topics)
                            _chip(
                              t.label(l),
                              topic == t,
                              () => setState(() => _topic = topic == t ? null : t),
                              dark: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                if (entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          all.isEmpty ? l.journeyEmpty : l.noMatches,
                          textAlign: TextAlign.center,
                          style: AppText.serif(20, color: AppColors.inkSoft),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _JourneyTile(answer: entries[i], lang: lang),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTile extends ConsumerWidget {
  const _JourneyTile({required this.answer, required this.lang});
  final Answer answer;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = Mood.byName(answer.mood);
    final isPrayer = answer.kind == AnswerKind.prayer;
    final tint = mood?.tint ?? (isPrayer ? AppColors.ember : AppColors.lavender);

    // Swipe left to remove, with Undo.
    return Dismissible(
      key: ValueKey(answer.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.heart, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        final l = AppLocalizations.of(context);
        final journey = ref.read(journeyProvider.notifier)..remove(answer.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l.entryRemoved),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 90), // above the bottom navigation
            action: SnackBarAction(label: l.undo, onPressed: () => journey.restore(answer)),
          ));
      },
      child: _card(context, ref, mood, isPrayer, tint),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Mood? mood, bool isPrayer, Color tint) {
    return Material(
      color: AppColors.ivoryCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.sand),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/answer/${answer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: mood != null
                    ? Text(mood.emoji, style: const TextStyle(fontSize: 24))
                    : Icon(
                        isPrayer ? Icons.volunteer_activism_rounded : Icons.chat_bubble_outline_rounded,
                        color: tint,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd(lang).format(answer.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      answer.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (answer.verses.isNotEmpty)
                      Text(answer.verses.first.reference, style: const TextStyle(fontSize: 13, color: AppColors.ember)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.read(journeyProvider.notifier).toggleFavorite(answer.id),
                icon: Icon(
                  answer.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: answer.favorite ? AppColors.heart : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
