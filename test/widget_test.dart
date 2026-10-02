import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/data/bible/bible_repository.dart';
import 'package:jesus_answers/data/models/answer.dart';
import 'package:jesus_answers/data/models/painting.dart';
import 'package:jesus_answers/services/answer/answer_service.dart';
import 'package:jesus_answers/services/answer/safety.dart';
import 'package:jesus_answers/services/answer/theme_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bible = BibleRepository(bundle: rootBundle);

  test('every day of the year has its own verse, in every language', () async {
    for (final lang in appLanguages) {
      final seen = <String>{};
      for (var d = DateTime(2025); d.year == 2025; d = d.add(const Duration(days: 1))) {
        final v = await bible.dailyVerse(d, lang.code);
        expect(v.text, isNotEmpty, reason: '${lang.code} $d');
        expect(v.reference, isNot(startsWith(v.ref.split(' ').first)), reason: '${lang.code} ${v.ref} book name');
        seen.add(v.ref);
      }
      expect(seen.length, 365, reason: '${lang.code}: a verse repeats within the year');
    }
    // Leap day falls back to Feb 28 rather than shifting the rest of the year.
    expect((await bible.dailyVerse(DateTime(2028, 2, 29), 'en')).ref,
        (await bible.dailyVerse(DateTime(2028, 2, 28), 'en')).ref);
    expect((await bible.dailyVerse(DateTime(2028, 12, 25), 'en')).ref, 'LUK 2:10-11');
  });

  test('a different painting of Jesus each day, every one bundled', () async {
    final all = await Painting.all(rootBundle);
    expect(all.length, greaterThanOrEqualTo(20));
    for (final p in all) {
      expect((await rootBundle.load(p.asset)).lengthInBytes, greaterThan(10000), reason: p.asset);
    }
    final today = DateTime(2026, 10, 2);
    final week = [for (var i = 0; i < 7; i++) (await Painting.forDay(today.add(Duration(days: i)))).asset];
    expect(week.toSet().length, 7, reason: 'no repeats within a week');
  });

  test('retrieves verbatim KJV text by theme', () async {
    final verses = await bible.versesFor(['anxiety', 'work'], 'en');
    expect(verses, isNotEmpty);
    final mat = await bible.verse('MAT 6:34', 'en');
    expect(mat!.text, startsWith('Take therefore no thought for the morrow'));
    expect(mat.reference, 'Matthew 6:34');
  });

  test('classifier picks sensible themes and ignores substrings', () {
    expect(ThemeClassifier.classify('I am stressed about my job').take(2), containsAll(['stress', 'work']));
    expect(ThemeClassifier.classify('I have been following since Monday'), ThemeClassifier.fallback);
  });

  test('crisis detection works across languages', () {
    expect(Safety.isCrisis('I want to end my life'), isTrue);
    expect(Safety.isCrisis('ఆత్మహత్య ఆలోచనలు వస్తున్నాయి'), isTrue);
    expect(Safety.isCrisis('मैं आत्महत्या के बारे में सोच रहा हूँ'), isTrue);
    expect(Safety.isCrisis('I am worried about my exam'), isFalse);
  });

  test('local answer is localized and grounded in real verses', () async {
    final service = LocalAnswerService(bible);
    final en = await service.answer(const AnswerRequest(question: 'I lost my job and I am scared', lang: 'en'));
    expect(en.verses, isNotEmpty);
    expect(en.prayer, endsWith('Amen.'));

    final te = await service.answer(const AnswerRequest(question: 'నాకు భయంగా ఉంది', lang: 'te', mood: 'afraid'));
    expect(te.verses.first.lang, 'te');
    expect(te.themes.first, 'fear');

    final crisis = await service.answer(const AnswerRequest(question: 'I want to die', lang: 'en'));
    expect(crisis.crisis, isTrue);
  });
}
