import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/question.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/question_service.dart';

/// "A) …" for sharing the question without its answer.
String _lettered(List<String> options) =>
    [for (final (i, o) in options.indexed) '${String.fromCharCode(65 + i)}) $o'].join('\n');

void _shareQuestion(AppLocalizations l, BibleQuestion q, DateTime day) => SharePlus.instance.share(ShareParams(
      text: '${l.quizShareText(q.question, _lettered(QuestionService.shuffled(q, day)))}\n\n${shareFooter(l)}',
    ));

/// Today's Bible question on Home: answer it, or see again what the Bible says.
class QuestionCard extends ConsumerWidget {
  const QuestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final service = ref.watch(questionServiceProvider);
    final questions = ref.watch(bibleQuestionsProvider).value;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final q = questions == null ? null : QuestionService.questionFor(questions, service.today);
        if (q == null) return const SizedBox.shrink();
        final answered = service.answerFor(service.today)?.id == q.id;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: () => context.push('/question'),
            child: GlassCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.quiz_rounded, size: 16, color: AppColors.goldSoft),
                      const SizedBox(width: 6),
                      Text(l.quizToday,
                          style: const TextStyle(
                              color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(q.question, textAlign: TextAlign.center, style: AppText.serif(21, color: Colors.white, height: 1.3)),
                  const SizedBox(height: 12),
                  answered
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.goldSoft),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(l.quizSeeWhy,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.midnight),
                          onPressed: () => context.push('/question'),
                          child: Text(l.quizAnswerNow),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The daily Bible question: four options; once answered, what the Bible says about it, from the
/// reader's own Bible, and a thought to take into the day. The past week's questions can still be answered.
class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  late DateTime _day = ref.read(questionServiceProvider).today;

  String _format(DateFormat Function(String) format, DateTime at) {
    try {
      return format(Localizations.localeOf(context).toString()).format(at);
    } catch (_) {
      return format('en').format(at);
    }
  }

  Future<void> _answer(BibleQuestion q, String choice) async {
    await ref.read(questionServiceProvider).answer(_day, q, choice);
    await ref.read(daysProvider).mark(); // a day with Jesus
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = ref.watch(questionServiceProvider);
    final questions = ref.watch(bibleQuestionsProvider).value;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final q = questions == null ? null : QuestionService.questionFor(questions, _day);
        final given = service.answerFor(_day);
        final answer = given != null && q != null && given.id == q.id ? given : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.quizTitle, style: AppText.serif(24, weight: FontWeight.w600)),
            actions: [
              if (q != null)
                IconButton(
                  tooltip: l.quizAsk,
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _shareQuestion(l, q, _day),
                ),
            ],
          ),
          body: q == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    // This week's questions: a missed day can still be answered.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (i, d) in service.days.indexed)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                avatar: service.answerFor(d) == null
                                    ? null
                                    : const Icon(Icons.check_rounded, size: 16, color: AppColors.ember),
                                label: Text(i == 0 ? l.quizTodayShort : _format(DateFormat.E, d)),
                                selected: d == _day,
                                onSelected: (_) => setState(() => _day = d),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (service.answered > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(l.quizScore('${service.right}', '${service.answered}'),
                            style: const TextStyle(color: AppColors.inkSoft)),
                      ),
                    const SizedBox(height: 14),
                    Text(q.question, style: AppText.serif(26, weight: FontWeight.w700, height: 1.25)),
                    const SizedBox(height: 4),
                    if (answer == null)
                      Text(l.quizPick, style: const TextStyle(color: AppColors.inkSoft)),
                    const SizedBox(height: 14),
                    for (final option in QuestionService.shuffled(q, _day)) ...[
                      _Option(
                        text: option,
                        state: answer == null
                            ? _OptionState.open
                            : option == q.answer
                                ? _OptionState.right
                                : option == answer.choice
                                    ? _OptionState.wrong
                                    : _OptionState.other,
                        onTap: () => _answer(q, option),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (answer != null) _Answer(question: q, right: answer.right, day: _day),
                  ],
                ),
        );
      },
    );
  }
}

enum _OptionState { open, right, wrong, other }

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.state, required this.onTap});
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color border, IconData? icon) = switch (state) {
      _OptionState.open => (AppColors.ivoryCard, AppColors.gold, null),
      _OptionState.right => (const Color(0xFFFFF0C2), AppColors.gold, Icons.check_circle_rounded),
      _OptionState.wrong => (const Color(0xFFFBE3E0), AppColors.heart, Icons.cancel_rounded),
      _OptionState.other => (AppColors.ivoryCard, AppColors.sand, null),
    };
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border, width: state == _OptionState.open ? 1 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: state == _OptionState.open ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: state == _OptionState.right ? FontWeight.w700 : FontWeight.w500,
                    color: state == _OptionState.other ? AppColors.inkSoft : AppColors.ink,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, color: state == _OptionState.wrong ? AppColors.heart : AppColors.ember),
            ],
          ),
        ),
      ),
    );
  }
}

/// Once answered: right or not, the passage that answers it, and a thought to take into the day.
class _Answer extends ConsumerWidget {
  const _Answer({required this.question, required this.right, required this.day});
  final BibleQuestion question;
  final bool right;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final q = question;
    final passage = ref.watch(prayerPassageProvider(q.passage)).value;
    final at = RegExp(r'^(\S+) (\d+):(\d+)').firstMatch(q.passage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Text(
          right ? l.quizRight : l.quizWrong(q.answer),
          style: AppText.serif(22, weight: FontWeight.w700, color: right ? AppColors.ember : AppColors.heart),
        ),
        // What happened, in plain words, so the passage makes sense.
        if (q.about.isNotEmpty) ...[
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.info_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(l.quizAbout, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember)),
                ]),
                const SizedBox(height: 8),
                Text(q.about, style: const TextStyle(fontSize: 17, height: 1.45)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(l.quizFromBible, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember)),
              ]),
              const SizedBox(height: 10),
              Text(passage?.text ?? '…', style: AppText.serif(19, height: 1.45)),
              const SizedBox(height: 8),
              Text('— ${passage?.reference ?? q.passage}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          color: const Color(0xFFFFF4D6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(l.quizThink, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ember)),
              ]),
              const SizedBox(height: 8),
              Text(q.think, style: const TextStyle(fontSize: 17, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (at != null)
              OutlinedButton.icon(
                onPressed: () => context.push('/bible/${at.group(1)}/${at.group(2)}?v=${at.group(3)}'),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(l.readChapter),
              ),
            if (q.story != null)
              OutlinedButton.icon(
                onPressed: () => context.push('/stories/${q.story}'),
                icon: const Icon(Icons.auto_stories_rounded, size: 18),
                label: Text(l.quizReadStory),
              ),
            OutlinedButton.icon(
              onPressed: () => _shareQuestion(l, q, day),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(l.quizAsk),
            ),
          ],
        ),
      ],
    );
  }
}
