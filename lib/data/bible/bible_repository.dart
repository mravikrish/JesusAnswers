import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/story.dart';
import '../models/verse.dart';

class _IndexEntry {
  const _IndexEntry(this.ref, this.themes);
  final String ref;
  final List<String> themes;
}

class _Translation {
  const _Translation(this.abbrev, this.attribution, this.books, this.verses, this.jesusWords);
  final String abbrev;
  final String attribution;
  final Map<String, String> books;
  final Map<String, String> verses;

  /// Ref → where Jesus speaks in that verse's text.
  final Map<String, List<(int, int)>> jesusWords;
}

/// The whole Bible in one language, for reading (`assets/bible/full/<lang>.json.gz`).
class _FullBible {
  const _FullBible(this.books, this.chapters, this.jesusWords);
  final Map<String, String> books;

  /// Book → chapters → verse text, verse n at index n-1 ("" where the
  /// translation has no such verse).
  final Map<String, List<List<String>>> chapters;
  final Map<String, List<(int, int)>> jesusWords;

  static _FullBible decode(Uint8List gz) {
    final j = jsonDecode(utf8.decode(GZipCodec().decode(gz))) as Map<String, dynamic>;
    return _FullBible(
      (j['books'] as Map).cast<String, String>(),
      {
        for (final MapEntry(:key, :value) in (j['chapters'] as Map).entries)
          key as String: [for (final c in value as List) (c as List).cast<String>()],
      },
      {for (final e in (j['wj'] as Map).entries) e.key as String: parseJesusWords(e.value)},
    );
  }
}

/// A book of the Bible, with the chapters there are to read in it.
class BibleBook {
  const BibleBook({
    required this.code,
    required this.name,
    required this.chapters,
    required this.oldTestament,
    this.keyVerse,
    this.picture,
  });

  /// USFM code, e.g. "MAT".
  final String code;
  final String name;
  final List<int> chapters;
  final bool oldTestament;

  /// The verse that sums the book up, e.g. "PSA 23:1" — shown on its card.
  final String? keyVerse;

  /// The book's own picture (assets/books/), or its Bible Story's until it has
  /// one; null when it has neither, and a painting of Jesus is shown instead.
  final String? picture;

  BibleBook withChapters(List<int> chapters) => BibleBook(
        code: code,
        name: name,
        chapters: chapters,
        oldTestament: oldTestament,
        keyVerse: keyVerse,
        picture: picture,
      );

  bool get isGospel => BibleRepository.gospels.contains(code);
}

/// Retrieves real Scripture by theme. The AI layer may *choose* references,
/// but verse text only ever comes from these bundled translations.
class BibleRepository {
  BibleRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<_IndexEntry>? _index;
  final _translations = <String, _Translation>{};

  /// 365 refs, Jan 1 → Dec 31, from assets/bible/daily.json.
  List<String>? _daily;

  Future<List<_IndexEntry>> _loadIndex() async {
    if (_index != null) return _index!;
    final j = jsonDecode(await _bundle.loadString('assets/bible/index.json'));
    return _index = [
      for (final v in j['verses'] as List)
        _IndexEntry(v['ref'] as String, (v['themes'] as List).cast<String>()),
    ];
  }

  Future<_Translation> _load(String lang) async {
    final cached = _translations[lang];
    if (cached != null) return cached;
    String raw;
    try {
      raw = await _bundle.loadString('assets/bible/$lang.json');
    } catch (_) {
      raw = await _bundle.loadString('assets/bible/en.json');
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return _translations[lang] = _Translation(
      j['translation'] as String,
      j['attribution'] as String,
      (j['books'] as Map).cast<String, String>(),
      (j['verses'] as Map).cast<String, String>(),
      {for (final e in ((j['wj'] as Map?) ?? const {}).entries) e.key as String: parseJesusWords(e.value)},
    );
  }

  Future<String> attribution(String lang) async => (await _load(lang)).attribution;

  /// Translation abbreviation in [lang], e.g. "KJV" or "IRV".
  Future<String> translation(String lang) async => (await _load(lang)).abbrev;

  /// Returns the verse for [ref] in [lang], or null if it isn't in the corpus.
  Future<Verse?> verse(String ref, String lang) async {
    final t = await _load(lang);
    final text = t.verses[ref];
    if (text == null) return null;
    final space = ref.indexOf(' ');
    final book = ref.substring(0, space);
    return Verse(
      ref: ref,
      reference: '${t.books[book] ?? book} ${ref.substring(space + 1)}',
      text: text,
      translation: t.abbrev,
      lang: lang,
      jesusWords: t.jesusWords[ref] ?? const [],
    );
  }

  /// Best-matching verses for [themes] (ordered by importance).
  /// [seed] varies the choice among equally good verses.
  Future<List<Verse>> versesFor(List<String> themes, String lang, {int count = 2, int seed = 0}) async {
    final index = await _loadIndex();
    final weight = {for (var i = 0; i < themes.length; i++) themes[i]: themes.length - i};
    final scored = <(String, int)>[];
    for (var i = 0; i < index.length; i++) {
      final e = index[i];
      // A verse whose primary (first) theme matches counts double — same rule as the backend.
      var score = 0;
      for (var j = 0; j < e.themes.length; j++) {
        score += (weight[e.themes[j]] ?? 0) * (j == 0 ? 2 : 1);
      }
      if (score > 0) scored.add((e.ref, score * 1000 + ((i * 7919 + seed) % 997)));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final refs = scored.isEmpty ? ['PSA 46:10', 'JHN 14:27'] : scored.take(count).map((s) => s.$1);
    return [for (final r in refs) ?await verse(r, lang)];
  }

  Future<List<String>> _loadDaily() async {
    if (_daily != null) return _daily!;
    final j = jsonDecode(await _bundle.loadString('assets/bible/daily.json'));
    return _daily = [
      for (final m in j['months'] as List) ...(m['refs'] as List).cast<String>(),
    ];
  }

  /// One verse per calendar day — a different one every day of the year.
  /// Uses the day's position in a non-leap year, so Feb 29 repeats Feb 28.
  Future<Verse> dailyVerse(DateTime day, String lang) async {
    final refs = await _loadDaily();
    return (await verse(refs[dayIndex(day) % refs.length], lang)) ?? (await verse('PSA 23:1', lang))!;
  }

  List<Story>? _stories;

  /// Bible Stories, in reading order, from assets/bible/stories.json.
  Future<List<Story>> stories() async {
    if (_stories != null) return _stories!;
    final j = jsonDecode(await _bundle.loadString('assets/bible/stories.json'));
    return _stories = [for (final s in j['stories'] as List) Story.fromJson(s as Map<String, dynamic>)];
  }

  /// [story]'s passages in [lang], verse by verse.
  Future<List<StoryPassage>> storyPassages(Story story, String lang) async {
    final t = await _load(lang);
    return [for (final p in story.passages) _passage(p, t)];
  }

  /// "LUK 15:11-32" → each verse stored for it (build_bible.dart stores story verses singly).
  static StoryPassage _passage(String passage, _Translation t) {
    final m = RegExp(r'^(\S+) (\d+):(\d+)(?:-(\d+))?$').firstMatch(passage)!;
    final book = m.group(1)!, ch = m.group(2)!;
    final from = int.parse(m.group(3)!);
    final to = int.parse(m.group(4) ?? m.group(3)!);
    return StoryPassage(
      reference: '${t.books[book] ?? book} ${passage.substring(passage.indexOf(' ') + 1)}',
      verses: [
        for (var v = from; v <= to; v++)
          if (t.verses['$book $ch:$v'] case final text?)
            NumberedVerse(v, text, t.jesusWords['$book $ch:$v'] ?? const []),
      ],
    );
  }

  static const gospels = {'MAT', 'MRK', 'LUK', 'JHN'};

  final _full = <String, Future<_FullBible>>{};

  /// The whole Bible in [lang] — about 10 MB of text, so it is unpacked off
  /// the UI thread, once per language.
  Future<_FullBible> _loadFull(String lang) => _full[lang] ??= () async {
        ByteData data;
        try {
          data = await _bundle.load('assets/bible/full/$lang.json.gz');
        } catch (_) {
          data = await _bundle.load('assets/bible/full/en.json.gz');
        }
        return compute(_FullBible.decode, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }();

  Map<String, ({String verse, String? picture})>? _bookInfo;

  /// Each book's key verse and picture, from assets/bible/books.json and the
  /// pictures actually bundled.
  Future<Map<String, ({String verse, String? picture})>> _loadBookInfo() async {
    if (_bookInfo != null) return _bookInfo!;
    final bundled = (await AssetManifest.loadFromAssetBundle(_bundle)).listAssets().toSet();
    String? found(String path) => bundled.contains(path) ? path : null;
    final j = jsonDecode(await _bundle.loadString('assets/bible/books.json'));
    return _bookInfo = {
      for (final b in j['books'] as List)
        b['code'] as String: (
          verse: b['verse'] as String,
          picture: found('assets/books/${b['code']}.jpg') ??
              (b['story'] == null ? null : found('assets/stories/${b['story']}.jpg')),
        ),
    };
  }

  /// All 66 books, Genesis to Revelation, every chapter.
  Future<List<BibleBook>> bibleBooks(String lang) async {
    final b = await _loadFull(lang);
    final info = await _loadBookInfo();
    var oldTestament = true;
    return [
      for (final MapEntry(key: code, value: chapters) in b.chapters.entries)
        BibleBook(
          code: code,
          name: b.books[code] ?? code,
          chapters: [for (var c = 1; c <= chapters.length; c++) c],
          oldTestament: oldTestament = oldTestament && code != 'MAT',
          keyVerse: info[code]?.verse,
          picture: info[code]?.picture,
        ),
    ];
  }

  /// [book]'s key verse in [lang], from the full Bible.
  Future<Verse?> keyVerse(BibleBook book, String lang) async =>
      book.keyVerse == null ? null : fullVerse(book.keyVerse!, lang);

  /// Any single verse ("JHN 14:27") from the full Bible in [lang], with its
  /// localized reference and the words of Jesus in it.
  Future<Verse?> fullVerse(String ref, String lang) async {
    final m = _verseRef.firstMatch(ref);
    if (m == null) return null;
    final book = m.group(1)!;
    final verses = await chapter(book, int.parse(m.group(2)!), lang);
    final v = verses.where((v) => v.number == int.parse(m.group(3)!)).firstOrNull;
    if (v == null) return null;
    return Verse(
      ref: ref,
      reference: '${(await _loadFull(lang)).books[book] ?? book} ${m.group(2)}:${m.group(3)}',
      text: v.text,
      translation: (await _load(lang)).abbrev,
      lang: lang,
      jesusWords: v.jesusWords,
    );
  }

  static final _verseRef = RegExp(r'^(\S+) (\d+):(\d+)$');

  /// The books of the Words of Jesus reader: the four Gospels whole, then
  /// each other book with the chapters in which He speaks.
  Future<List<BibleBook>> jesusBooks(String lang) async {
    final b = await _loadFull(lang);
    final spoken = <String, Set<int>>{};
    for (final ref in b.jesusWords.keys) {
      final space = ref.indexOf(' ');
      (spoken[ref.substring(0, space)] ??= {}).add(int.parse(ref.substring(space + 1, ref.indexOf(':'))));
    }
    return [
      for (final book in await bibleBooks(lang))
        if (book.isGospel)
          book
        else if (spoken[book.code] case final chapters?)
          book.withChapters(chapters.toList()..sort()),
    ];
  }

  /// [book] [chapter] in [lang], verse by verse, with His words marked.
  Future<List<NumberedVerse>> chapter(String book, int chapter, String lang) async {
    final b = await _loadFull(lang);
    final chapters = b.chapters[book] ?? const [];
    if (chapter < 1 || chapter > chapters.length) return const [];
    final verses = chapters[chapter - 1];
    return [
      for (var i = 0; i < verses.length; i++)
        if (verses[i].isNotEmpty) NumberedVerse(i + 1, verses[i], b.jesusWords['$book $chapter:${i + 1}'] ?? const []),
    ];
  }

  /// 0 (Jan 1) … 364 (Dec 31).
  static int dayIndex(DateTime day) {
    final date = (day.month == 2 && day.day == 29) ? 28 : day.day;
    return DateTime.utc(2023, day.month, date).difference(DateTime.utc(2023)).inDays;
  }
}
