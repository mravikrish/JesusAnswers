import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/data/bible/bible_repository.dart';
import 'package:jesus_answers/data/models/question.dart';
import 'package:jesus_answers/features/question/question_screen.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';
import 'package:jesus_answers/providers.dart';
import 'package:jesus_answers/services/question_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  const daniel = BibleQuestion(
    id: 'lions_den',
    passage: 'DAN 6:16-23',
    story: 'daniel',
    question: "Who was thrown into the lions' den for praying to God?",
    options: ['Daniel', 'Joseph', 'Elijah', 'Jeremiah'],
    about: 'Jealous officials tricked King Darius into a law against praying.',
    think: 'Daniel kept praying even when it was forbidden.',
  );
  const noah = BibleQuestion(
    id: 'noah_ark',
    passage: 'GEN 6:13-22',
    question: 'Who built an ark?',
    options: ['Noah', 'Abraham', 'Moses', 'Jonah'],
    about: 'The world was full of violence, but Noah walked with God.',
    think: 'Noah obeyed.',
  );

  test('one question a day, the same for everyone, in turn', () {
    final day = DateTime(2026, 10, 9);
    expect(QuestionService.questionFor([daniel, noah], day), QuestionService.questionFor([daniel, noah], day));
    expect(QuestionService.questionFor([daniel, noah], day), isNot(QuestionService.questionFor([daniel, noah], DateTime(2026, 10, 10))));
    expect(QuestionService.questionFor([daniel, noah], DateTime(2026)), daniel);
    expect(QuestionService.questionFor([daniel, noah], DateTime(2025, 12, 31)), noah); // before the start, still in turn
    expect(QuestionService.questionFor(const [], day), isNull);
  });

  test('options are shuffled, but the same each time', () {
    final day = DateTime(2026, 10, 9);
    final once = QuestionService.shuffled(daniel, day);
    expect(once, QuestionService.shuffled(daniel, day));
    expect(once.toSet(), daniel.options.toSet());
    // Not always the right one first.
    final firsts = {for (var d = 1; d <= 20; d++) QuestionService.shuffled(daniel, DateTime(2026, 10, d)).first};
    expect(firsts.length, greaterThan(1));
  });

  test('answers are kept on the phone, once a day, and counted', () async {
    final p = await prefs();
    final now = DateTime(2026, 10, 9, 20);
    final service = QuestionService(p, now: () => now);
    expect(service.days.length, QuestionService.daysBack);
    expect(service.days.first, DateTime(2026, 10, 9));

    await service.answer(DateTime(2026, 10, 9), daniel, 'Joseph');
    await service.answer(DateTime(2026, 10, 9), daniel, 'Daniel'); // no second try
    await service.answer(DateTime(2026, 10, 8), noah, 'Noah');
    expect(service.answerFor(DateTime(2026, 10, 9)), (id: 'lions_den', choice: 'Joseph', right: false));
    expect((service.answered, service.right), (2, 1));

    final again = QuestionService(p, now: () => now);
    expect(again.answerFor(DateTime(2026, 10, 8))?.right, isTrue);
  });

  test('all 90 questions in every language: four options, and a passage in that Bible', () async {
    final bible = BibleRepository();
    final index = jsonDecode(await rootBundle.loadString('assets/questions/questions.json'))['questions'] as List;
    expect(index.length, 90);
    for (final lang in [for (final l in appLanguages) l.locale.languageCode]) {
      final questions = await bible.questions(lang);
      expect(questions.length, 90, reason: lang);
      for (final q in questions) {
        expect(q.options.toSet().length, 4, reason: '$lang ${q.id}');
        expect(q.question.trim(), isNotEmpty, reason: '$lang ${q.id}');
        expect(q.about.trim(), isNotEmpty, reason: '$lang ${q.id}');
        expect(q.think.trim(), isNotEmpty, reason: '$lang ${q.id}');
      }
      // Each passage is in the reader's own Bible (checked here for the first and the last).
      for (final q in [questions.first, questions.last]) {
        expect(await bible.prayerPassage(q.passage, lang), isNotNull, reason: '$lang ${q.passage}');
      }
    }
  });

  testWidgets('answering shows whether it was right, what the Bible says, and a thought', (tester) async {
    final p = await tester.runAsync(() => prefs());
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final q = QuestionService.questionFor([daniel], day)!;
    final wrong = QuestionService.shuffled(q, day).firstWhere((o) => o != q.answer);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(p!),
        bibleQuestionsProvider.overrideWith((_) async => [daniel]),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: QuestionScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(daniel.question), findsOneWidget);
    expect(find.text('Think on this'), findsNothing);
    await tester.tap(find.text(wrong));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();

    expect(find.text('Not quite. The answer is: Daniel'), findsOneWidget);
    expect(find.text('About this story'), findsOneWidget);
    expect(find.text(daniel.about), findsOneWidget);
    expect(find.text('What the Bible says'), findsOneWidget);
    expect(find.text('Think on this'), findsOneWidget);
    expect(find.text(daniel.think), findsOneWidget);
    expect(find.text('Read the whole story'), findsOneWidget);
    expect(find.textContaining('Daniel', findRichText: true), findsWidgets);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(ProviderScope.containerOf(tester.element(find.byType(QuestionScreen))).read(daysProvider).today, isTrue);
  });
}
