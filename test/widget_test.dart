import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/data/bible/bible_repository.dart';
import 'package:jesus_answers/data/models/answer.dart';
import 'package:jesus_answers/data/models/painting.dart';
import 'package:jesus_answers/features/jesus_words/speak_screen.dart';
import 'package:jesus_answers/providers.dart';
import 'package:jesus_answers/services/answer/answer_service.dart';
import 'package:jesus_answers/services/answer/safety.dart';
import 'package:jesus_answers/services/answer/theme_classifier.dart';
import 'package:jesus_answers/services/voice/natural_voices.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('every Bible story is titled and told in full Scripture, in every language', () async {
    final stories = await bible.stories();
    expect(stories.length, greaterThanOrEqualTo(35));
    expect(stories.map((s) => s.id).toSet().length, stories.length, reason: 'story ids are unique');
    for (final s in stories) {
      expect((await rootBundle.load(s.image.asset)).lengthInBytes, greaterThan(20000), reason: s.image.asset);
    }
    expect(stories.where((s) => s.oldTestament), isNotEmpty);
    expect(stories.where((s) => !s.oldTestament), isNotEmpty);
    for (final lang in appLanguages) {
      for (final s in stories) {
        expect(s.titles[lang.code], isNotEmpty, reason: '${lang.code} ${s.id} title');
        final passages = await bible.storyPassages(s, lang.code);
        expect(passages.length, s.passages.length);
        for (final p in passages) {
          expect(p.verses, isNotEmpty, reason: '${lang.code} ${s.id} ${p.reference}');
          expect(p.reference, isNot(matches(RegExp('^[1-3]?[A-Z]{2,3} '))), reason: '${lang.code} book name');
        }
      }
    }
    final prodigal = (await bible.storyPassages(stories.firstWhere((s) => s.id == 'prodigal_son'), 'en')).single;
    expect(prodigal.reference, 'Luke 15:11-32');
    expect(prodigal.verses.length, 22);
    expect(prodigal.verses.first.text, startsWith('And he said, A certain man had two sons'));
  });

  test('the whole Bible can be read, every book and chapter, in every language', () async {
    for (final lang in appLanguages) {
      final books = await bible.bibleBooks(lang.code);
      expect(books.length, 66, reason: lang.code);
      expect(books.where((b) => b.oldTestament).length, 39, reason: lang.code);
      final chapters = {for (final b in books) b.code: b.chapters.length};
      expect([chapters['GEN'], chapters['PSA'], chapters['MAT'], chapters['REV']], [50, 150, 28, 22], reason: lang.code);
      var verses = 0;
      for (final b in books) {
        expect((await bible.keyVerse(b, lang.code))?.text, isNotEmpty, reason: '${lang.code} ${b.code} key verse');
        expect(b.name, isNot(b.code), reason: '${lang.code} ${b.code} book name');
        expect(b.name.length, lessThan(30), reason: '${lang.code} ${b.code} book name is a title, not a name');
        for (final c in b.chapters) {
          final list = await bible.chapter(b.code, c, lang.code);
          expect(list, isNotEmpty, reason: '${lang.code} ${b.code} $c');
          verses += list.length;
        }
      }
      expect(verses, greaterThan(30900), reason: lang.code);
    }
    final books = {for (final b in await bible.bibleBooks('en')) b.code: b};
    // Until a book has its own picture, its Bible Story's stands in.
    for (final b in books.values) {
      if (b.picture case final p?) expect((await rootBundle.load(p)).lengthInBytes, greaterThan(20000), reason: p);
    }
    expect(books['GEN']!.picture, anyOf('assets/books/GEN.jpg', 'assets/stories/creation.jpg'));
    final key = (await bible.keyVerse(books['PSA']!, 'en'))!;
    expect([key.reference, key.text], ['Psalm 23:1', startsWith('A Psalm of David. The LORD is my shepherd')]);
    final psalm = await bible.chapter('PSA', 23, 'en');
    expect(psalm.first.text, endsWith('The LORD is my shepherd; I shall not want.'));
    expect(psalm.length, 6);
  });

  test('the four Gospels are whole, with the words of Jesus marked, in every language', () async {
    for (final lang in appLanguages) {
      final books = await bible.jesusBooks(lang.code);
      expect(books.take(4).map((b) => b.code), ['MAT', 'MRK', 'LUK', 'JHN'], reason: lang.code);
      expect([for (final b in books.take(4)) b.chapters.length], [28, 16, 24, 21], reason: lang.code);
      expect(books.map((b) => b.code), containsAll(['ACT', 'REV']), reason: lang.code);
      var spoken = 0;
      for (final b in books) {
        for (final c in b.chapters) {
          final verses = await bible.chapter(b.code, c, lang.code);
          expect(verses, isNotEmpty, reason: '${lang.code} ${b.code} $c');
          if (!b.isGospel) expect(verses.where((v) => v.jesusWords.isNotEmpty), isNotEmpty, reason: '${lang.code} ${b.code} $c');
          for (final v in verses) {
            var pos = 0;
            for (final (s, e) in v.jesusWords) {
              expect(s >= pos && s < e && e <= v.text.length, isTrue, reason: '${lang.code} ${b.code} $c:${v.number}');
              pos = e;
            }
            if (v.jesusWords.isNotEmpty) spoken++;
          }
        }
      }
      // Red-letter editions mark roughly two thousand verses.
      expect(spoken, inInclusiveRange(1900, 2200), reason: lang.code);
    }
    final follow = (await bible.chapter('MAT', 4, 'en')).firstWhere((v) => v.number == 19);
    expect(follow.spoken, 'Follow me, and I will make you fishers of men.');
    // Verses chosen by theme carry His words too.
    expect((await bible.verse('JHN 14:27', 'en'))!.jesusWords, isNotEmpty);
    expect((await bible.verse('PSA 23:1', 'en'))!.jesusWords, isEmpty);
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

  test('every gallery picture carries its own verse, short enough for a status, in every language', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final count = (await Painting.all(rootBundle)).length;
    for (final lang in appLanguages) {
      await prefs.setString('lang', lang.code);
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      final verses = [for (var i = 0; i < count; i++) await c.read(pictureVerseProvider(i).future)];
      expect(verses.map((v) => v.ref).toSet().length, count, reason: '${lang.code}: two pictures share a verse');
      for (final v in verses) {
        // PictureCard shrinks long verses; past ~400 characters they would crowd the picture.
        expect(v.text.length, lessThan(400), reason: '${lang.code} ${v.ref}');
      }
      c.dispose();
    }
  });

  test('Hear Him speak has His words for every famous saying, in every language', () async {
    expect((await rootBundle.load(speakingPortrait)).lengthInBytes, greaterThan(100000));
    for (final lang in appLanguages) {
      for (final ref in famousSayings) {
        final v = await bible.fullVerse(ref, lang.code);
        expect(v?.spoken, isNotEmpty, reason: '${lang.code} $ref');
      }
    }
    final rest = (await bible.fullVerse('MAT 11:28', 'en'))!;
    expect(rest.spoken, 'Come unto me, all ye that labour and are heavy laden, and I will give you rest.');
  });

  test('natural voices: one per language and role, free to use, credited', () {
    final codes = {for (final l in appLanguages) l.code};
    final seen = <String>{};
    for (final v in naturalVoices) {
      expect(codes, contains(v.lang), reason: v.id);
      expect(seen.add('${v.lang}/${v.role}'), isTrue, reason: '${v.id}: two voices for one language and role');
      expect(v.id, startsWith(v.lang), reason: v.id);
      expect(v.credit, isNotEmpty, reason: v.id);
      expect(v.lengthScale, inInclusiveRange(1.0, 1.8), reason: v.id);
      expect(v.file('${v.id}.onnx').toString(), 'https://huggingface.co/csukuangfj/vits-piper-${v.id}/resolve/main/${v.id}.onnx');
    }
    // His words in a male voice, the rest in a female one; skipped languages keep the phone's voice.
    expect(naturalVoiceFor('de', VoiceRole.jesus)!.name, 'Thorsten');
    expect(naturalVoiceFor('de', VoiceRole.verse)!.name, 'Kerstin');
    expect(naturalVoiceFor('te', VoiceRole.jesus), isNull);
    expect(naturalVoiceFor('uk', VoiceRole.jesus), isNull);
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
    expect(Safety.isCrisis('Ya no quiero vivir'), isTrue);
    expect(Safety.isCrisis('Estou pensando em suicídio'), isTrue);
    expect(Safety.isCrisis('Je veux mourir'), isTrue);
    expect(Safety.isCrisis('Nataka kufa'), isTrue);
    expect(Safety.isCrisis('Gusto ko nang mamatay'), isTrue);
    expect(Safety.isCrisis('Ich denke an Selbstmord'), isTrue);
    expect(Safety.isCrisis('Voglio morire'), isTrue);
    expect(Safety.isCrisis('Myślę o samobójstwie'), isTrue);
    expect(Safety.isCrisis('Я не хочу жить'), isTrue);
    expect(Safety.isCrisis('Думаю про самогубство'), isTrue);
    expect(Safety.isCrisis('I am worried about my exam'), isFalse);
    expect(Safety.isCrisis('Estoy preocupado por mi examen'), isFalse);
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
