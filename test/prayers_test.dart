import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/data/bible/bible_repository.dart';
import 'package:jesus_answers/features/prayer/prayers_screen.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Tests have no network: the fallback font is fine for checking that words fit.
  GoogleFonts.config.allowRuntimeFetching = false;

  final index = jsonDecode(File('assets/prayers/prayers.json').readAsStringSync());
  final prayers = [for (final g in index['groups'] as List) ...(g['prayers'] as List).cast<Map>()];
  final en = jsonDecode(File('assets/prayers/en.json').readAsStringSync());

  test('every language has every ready prayer, with words for the ones not from Scripture', () {
    for (final lang in appLanguages) {
      final j = jsonDecode(File('assets/prayers/${lang.code}.json').readAsStringSync());
      for (final g in index['groups'] as List) {
        expect((j['groups'][g['id']] as String?)?.isNotEmpty, isTrue, reason: '${lang.code} group ${g['id']}');
      }
      for (final p in prayers) {
        final words = j['prayers'][p['id']] as Map?;
        expect((words?['title'] as String?)?.isNotEmpty, isTrue, reason: '${lang.code} ${p['id']} title');
        if (p['passage'] == null) {
          expect((words?['text'] as String?)?.isNotEmpty, isTrue, reason: '${lang.code} ${p['id']} text');
        }
        // Prayed for someone else in English, so in every language — with a place for their name.
        if (en['prayers'][p['id']]['forText'] != null) {
          expect(words?['forText'] as String?, contains('{name}'), reason: '${lang.code} ${p['id']} forText');
        }
        if (en['prayers'][p['id']]['forTitle'] != null) {
          expect((words?['forTitle'] as String?)?.isNotEmpty, isTrue, reason: '${lang.code} ${p['id']} forTitle');
        }
        expect(p['picture'], isNotNull, reason: '${p['id']} picture');
        expect(File('assets/jesus/${p['picture']}').existsSync(), isTrue, reason: '${p['id']} picture file');
      }
    }
  });

  testWidgets('the longest prayers fit on a status picture in every language', (tester) async {
    final bible = BibleRepository();
    for (final lang in ['en', 'ta', 'ml', 'de']) {
      final all = (await tester.runAsync(() => bible.prayerGroups(lang)))!.expand((g) => g.prayers).toList();
      final psalm91 = all.firstWhere((p) => p.id == 'psalm91');
      final passage = await tester.runAsync(() => bible.prayerPassage(psalm91.passage!, lang));
      final longest = all.where((p) => p.text != null).reduce((a, b) => a.text!.length > b.text!.length ? a : b);
      for (final (prayer, text) in [(psalm91, passage!.text), (longest, longest.text!)]) {
        await tester.pumpWidget(MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(child: PrayerPictureCard(prayer: prayer, title: prayer.title, text: text)),
        ));
        expect(tester.takeException(), isNull, reason: '$lang ${prayer.id}');
      }
    }
  });

  test('a prayer for someone carries their name', () async {
    final groups = await BibleRepository().prayerGroups('en');
    final journey = groups.expand((g) => g.prayers).firstWhere((p) => p.id == 'journey');
    expect(journey.canPrayForSomeone, isTrue);
    expect(journey.words(name: ' Ravi '), allOf(contains('Ravi is about to travel'), isNot(contains('{name}'))));
    expect(journey.words(), journey.text);
    expect(journey.picture?.asset, 'assets/jesus/07.jpg');
  });

  test('every Scripture prayer is found in every language', () async {
    final bible = BibleRepository();
    for (final lang in appLanguages) {
      final groups = await bible.prayerGroups(lang.code);
      expect(groups.expand((g) => g.prayers), hasLength(prayers.length));
      for (final p in prayers.where((p) => p['passage'] != null)) {
        final passage = await bible.prayerPassage(p['passage'] as String, lang.code);
        expect(passage?.text.isNotEmpty, isTrue, reason: '${lang.code} ${p['passage']}');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
