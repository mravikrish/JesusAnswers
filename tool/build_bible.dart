// Builds assets/bible/<lang>.json (the verses the app quotes) and
// assets/bible/full/<lang>.json.gz (the whole Bible, for reading) from
// published Bible translations.
//
// Usage:  dart run tool/build_bible.dart
//
// Verse text is copied verbatim from eBible.org distributions — never
// generated or translated by AI. Downloads are cached in .dart_tool/bible_cache.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';

class Source {
  const Source(this.lang, this.ebibleId, this.abbrev, this.name, this.license);
  final String lang;
  final String ebibleId;
  final String abbrev;
  final String name;
  final String license;
}

const _irv = 'Indian Revised Version © 2017, 2019 Bridge Connectivity Solutions. '
    'Licensed CC BY-SA 4.0.';

const sources = [
  Source('en', 'eng-kjv2006', 'KJV', 'King James Version', 'Public domain.'),
  Source('hi', 'hin2017', 'IRV', 'इंडियन रिवाइज्ड वर्जन', _irv),
  Source('te', 'tel2017', 'IRV', 'ఇండియన్ రివైజ్డ్ వెర్షన్', _irv),
  Source('ta', 'tam2017', 'IRV', 'இண்டியன் ரிவைஸ்டு வெர்ஸன்', _irv),
  Source('kn', 'kanirv', 'IRV', 'ಇಂಡಿಯನ್ ರಿವೈಜ್ಡ್ ವರ್ಸನ್', _irv),
  Source('ml', 'mal', 'IRV', 'ഇന്ത്യൻ റിവൈസ്ഡ് വേർഷൻ', _irv),
  Source('mr', 'mar', 'IRV', 'इंडियन रीवाइज्ड वर्जन', _irv),
  Source('pa', 'pan', 'IRV', 'ਇੰਡਿਅਨ ਰਿਵਾਇਜ਼ਡ ਵਰਜ਼ਨ', _irv),
  Source('bn', 'benirv', 'IRV', 'ইন্ডিয়ান রিভাইজড ভার্সন', _irv),
  Source('gu', 'guj2017', 'IRV', 'ઇન્ડિયન રીવાઇઝ્ડ વર્ઝન', _irv),
  Source('or', 'ory', 'IRV', 'ଇଣ୍ଡିୟାନ ରିୱାଇସ୍ଡ୍ ୱରସନ୍', _irv),
];

const englishBooks = {
  'GEN': 'Genesis', 'EXO': 'Exodus', 'LEV': 'Leviticus', 'NUM': 'Numbers',
  'DEU': 'Deuteronomy', 'JOS': 'Joshua', 'JDG': 'Judges', 'RUT': 'Ruth',
  '1SA': '1 Samuel', '2SA': '2 Samuel', '1KI': '1 Kings', '2KI': '2 Kings',
  '1CH': '1 Chronicles', '2CH': '2 Chronicles', 'EZR': 'Ezra', 'NEH': 'Nehemiah',
  'EST': 'Esther', 'JOB': 'Job', 'PSA': 'Psalm', 'PRO': 'Proverbs',
  'ECC': 'Ecclesiastes', 'SNG': 'Song of Solomon', 'ISA': 'Isaiah', 'JER': 'Jeremiah',
  'LAM': 'Lamentations', 'EZK': 'Ezekiel', 'DAN': 'Daniel', 'HOS': 'Hosea',
  'JOL': 'Joel', 'AMO': 'Amos', 'OBA': 'Obadiah', 'JON': 'Jonah', 'MIC': 'Micah',
  'NAM': 'Nahum', 'HAB': 'Habakkuk', 'ZEP': 'Zephaniah', 'HAG': 'Haggai',
  'ZEC': 'Zechariah', 'MAL': 'Malachi',
  'MAT': 'Matthew', 'MRK': 'Mark', 'LUK': 'Luke', 'JHN': 'John', 'ACT': 'Acts',
  'ROM': 'Romans', '1CO': '1 Corinthians', '2CO': '2 Corinthians', 'GAL': 'Galatians',
  'EPH': 'Ephesians', 'PHP': 'Philippians', 'COL': 'Colossians',
  '1TH': '1 Thessalonians', '2TH': '2 Thessalonians', '1TI': '1 Timothy',
  '2TI': '2 Timothy', 'TIT': 'Titus', 'PHM': 'Philemon', 'HEB': 'Hebrews',
  'JAS': 'James', '1PE': '1 Peter', '2PE': '2 Peter', '1JN': '1 John',
  '2JN': '2 John', '3JN': '3 John', 'JUD': 'Jude', 'REV': 'Revelation',
};

/// eBible VPL files use BibleWorks-style codes where they differ from USFM.
const _vplCodes = {
  'MRK': 'MAR', 'JHN': 'JOH', 'PHP': 'PHI', 'JAS': 'JAM', '1JN': '1JO',
  '2JN': '2JO', '3JN': '3JO', 'SNG': 'SOL', 'EZK': 'EZE', 'JOL': 'JOE',
  'NAM': 'NAH', 'JUD': 'JUD',
};

final _refPattern =RegExp(r'^([1-3]?[A-Z]{2,3}) (\d+):(\d+)(?:-(\d+))?$');

Future<void> main() async {
  final index = jsonDecode(File('tool/bible/themes.json').readAsStringSync());
  final daily = jsonDecode(File('tool/bible/daily.json').readAsStringSync());
  final stories = jsonDecode(File('tool/bible/stories.json').readAsStringSync());
  final bookInfo = (jsonDecode(File('tool/bible/books.json').readAsStringSync())['books'] as List)
      .cast<Map<String, dynamic>>();
  final storyVerses = {
    for (final s in stories['stories'])
      for (final p in (s['passages'] as List).cast<String>()) ..._singleVerses(p),
  };
  final cache = Directory('.dart_tool/bible_cache')..createSync(recursive: true);
  final outDir = Directory('assets/bible')..createSync(recursive: true);
  var problems = 0;

  // Words of Jesus, per language: which verses He speaks in, and the exact
  // spans, from the \wj markers of each translation's USFM.
  final speech = <String, Map<String, List<(String, bool)>>>{};
  for (final src in sources) {
    final usfm = await _fetchZip(cache, '${src.ebibleId}_usfm.zip');
    final segments = <String, List<(String, bool)>>{};
    for (final f in usfm.files) {
      final m = RegExp(r'\d+-([1-3]?[A-Z]{2,3})').firstMatch(f.name);
      if (m == null || !_newTestament.contains(m.group(1))) continue;
      segments.addAll(_usfmSegments(m.group(1)!, utf8.decode(f.content as List<int>)));
    }
    speech[src.lang] = segments;
  }

  final refs = {
    for (final v in index['verses']) v['ref'] as String,
    for (final m in daily['months']) ...(m['refs'] as List).cast<String>(),
    // Stories are shown verse by verse, so each verse of a passage is stored on its own.
    ...storyVerses,
  }.toList();
  final books = {for (final r in refs) _refPattern.firstMatch(r)!.group(1)!};
  final overrides = jsonDecode(File('tool/bible/book_name_overrides.json').readAsStringSync())
      as Map<String, dynamic>;
  final fullDir = Directory('${outDir.path}/full')..createSync(recursive: true);

  for (final src in sources) {
    stdout.writeln('▸ ${src.lang} (${src.ebibleId})');
    final vpl = await _fetchZip(cache, '${src.ebibleId}_vpl.zip');
    final vplFile = vpl.files.firstWhere((f) => f.name.endsWith('_vpl.txt'));
    final lines = _parseVpl(utf8.decode(vplFile.content as List<int>));

    // Every book's name: the full Bible lists all 66.
    final allNames = <String, String>{};
    if (src.lang == 'en') {
      allNames.addAll(englishBooks);
    } else {
      final usfm = await _fetchZip(cache, '${src.ebibleId}_usfm.zip');
      for (final f in usfm.files) {
        final m = RegExp(r'\d+-([1-3]?[A-Z]{2,3})').firstMatch(f.name);
        if (m == null || !englishBooks.containsKey(m.group(1))) continue;
        final name = _bookName(utf8.decode(f.content as List<int>));
        if (name != null) allNames[m.group(1)!] = name;
      }
      final langOverrides = overrides[src.lang] as Map<String, dynamic>? ?? {};
      langOverrides.forEach((b, n) => allNames[b] = n as String);
    }
    for (final b in englishBooks.keys) {
      if (!allNames.containsKey(b)) {
        problems++;
        stderr.writeln('  ! ${src.lang}: no book name for $b');
      }
    }
    final bookNames = {for (final b in books) b: ?allNames[b]};

    // Red letters for one verse's cleaned text, from this translation's \wj markers.
    var unaligned = 0;
    List<List<int>> speechIn(String key, String text) {
      final segs = speech[src.lang]![key];
      if (segs == null || !segs.any((s) => s.$2)) return const [];
      final found = _speechSpans(segs, text);
      if (found == null) {
        unaligned++;
        stderr.writeln('  ? ${src.lang}: $key — Jesus\' words could not be lined up');
      }
      return found ?? const [];
    }

    final verses = <String, String>{};
    final wj = <String, List<List<int>>>{};
    for (final ref in refs) {
      final m = _refPattern.firstMatch(ref)!;
      final book = m.group(1)!, ch = m.group(2)!;
      final from = int.parse(m.group(3)!);
      final to = int.parse(m.group(4) ?? m.group(3)!);
      final present = [
        for (var v = from; v <= to; v++)
          if (lines['${_vplCodes[book] ?? book} $ch:$v'] case final t? when t.isNotEmpty) (v, _clean(t)),
      ];
      final parts = [for (final (_, t) in present) t];
      // Some translations bridge verses ("4-5" printed as 4), so a story verse
      // missing right after one that exists is already in the text.
      final bridged = parts.isEmpty &&
          storyVerses.contains(ref) &&
          lines.containsKey('${_vplCodes[book] ?? book} $ch:${from - 1}');
      if (bridged) {
        stdout.writeln('  · ${src.lang}: $ref is bridged into the verse before');
      } else if (parts.length != to - from + 1) {
        problems++;
        stderr.writeln('  ! ${src.lang}: $ref incomplete (${parts.length}/${to - from + 1})');
      }
      if (parts.isEmpty) continue;
      verses[ref] = parts.join(' ');

      // Red letters: each part's spans, shifted to where the part sits in the joined text.
      final spans = <List<int>>[];
      var offset = 0;
      for (final (v, t) in present) {
        spans.addAll([for (final s in speechIn('$book $ch:$v', t)) [s[0] + offset, s[1] + offset]]);
        offset += t.length + 1;
      }
      if (spans.isNotEmpty) wj[ref] = spans;
    }

    final out = {
      'lang': src.lang,
      'translation': src.abbrev,
      'translationName': src.name,
      'attribution': '${src.name} (${src.abbrev}). ${src.license} Source: eBible.org/${src.ebibleId}',
      'books': bookNames,
      'verses': verses,
      // Words of Jesus: [start, end) UTF-16 offsets into each verse's text.
      'wj': wj,
    };
    File('${outDir.path}/${src.lang}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
    stdout.writeln('  ${verses.length}/${refs.length} verses, ${bookNames.length} book names');

    // The whole Bible, for reading: each book's chapters as lists of verse
    // text, verse n at index n-1 ("" where a translation has no such verse —
    // bridged into the one before, or absent from its manuscripts).
    final chapters = <String, List<List<String>>>{};
    final fullWj = <String, List<List<int>>>{};
    var count = 0;
    for (final b in englishBooks.keys) {
      final prefix = '${_vplCodes[b] ?? b} ';
      final book = <List<String>>[];
      for (final MapEntry(key: k, value: t) in lines.entries) {
        if (!k.startsWith(prefix) || t.isEmpty) continue;
        final cv = k.substring(prefix.length).split(':');
        final c = int.parse(cv[0]), v = int.parse(cv[1]);
        if (c < 1 || v < 1) continue;
        while (book.length < c) {
          book.add([]);
        }
        final verseList = book[c - 1];
        while (verseList.length < v) {
          verseList.add('');
        }
        final text = verseList[v - 1] = _clean(t);
        count++;
        if (_newTestament.contains(b)) {
          final spans = speechIn('$b $c:$v', text);
          if (spans.isNotEmpty) fullWj['$b $c:$v'] = spans;
        }
      }
      if (book.isEmpty || book.any((c) => c.isEmpty)) {
        problems++;
        stderr.writeln('  ! ${src.lang}: $b has a missing chapter');
      }
      chapters[b] = book;
    }
    problems += unaligned;
    if (_quoteTrims > 0) stdout.writeln('  · ${src.lang}: $_quoteTrims span(s) ended at a closing quote');
    _quoteTrims = 0;
    // Each book's key verse, shown on its card, must be there to show.
    for (final info in bookInfo) {
      final m = _refPattern.firstMatch(info['verse'] as String);
      final text = m == null
          ? null
          : chapters[m.group(1)]?.elementAtOrNull(int.parse(m.group(2)!) - 1)?.elementAtOrNull(int.parse(m.group(3)!) - 1);
      if (m == null || m.group(1) != info['code'] || m.group(4) != null || (text ?? '').isEmpty) {
        problems++;
        stderr.writeln('  ! ${src.lang}: key verse ${info['verse']} of ${info['code']} is missing');
      }
    }
    final full = {'books': allNames, 'chapters': chapters, 'wj': fullWj};
    final gz = GZipCodec(level: 9).encode(utf8.encode(jsonEncode(full)));
    File('${fullDir.path}/${src.lang}.json.gz').writeAsBytesSync(gz);
    stdout.writeln('  full Bible: $count verses, ${fullWj.length} with words of Jesus, ${gz.length ~/ 1024} KB');
  }

  File('tool/bible/themes.json').copySync('${outDir.path}/index.json');
  File('tool/bible/daily.json').copySync('${outDir.path}/daily.json');
  File('tool/bible/stories.json').copySync('${outDir.path}/stories.json');
  final storyIds = {for (final s in stories['stories']) s['id']};
  if (bookInfo.map((b) => b['code']).join(' ') != englishBooks.keys.join(' ')) {
    problems++;
    stderr.writeln('  ! tool/bible/books.json must list all 66 books, Genesis → Revelation');
  }
  for (final b in bookInfo) {
    if (b['story'] != null && !storyIds.contains(b['story'])) {
      problems++;
      stderr.writeln('  ! tool/bible/books.json: ${b['code']} names unknown story ${b['story']}');
    }
  }
  File('tool/bible/books.json').copySync('${outDir.path}/books.json');
  stdout.writeln(problems == 0 ? '✓ done' : '⚠ done with $problems problem(s)');
  if (problems > 0) exitCode = 1;
}

/// "LUK 15:3-5" → ["LUK 15:3", "LUK 15:4", "LUK 15:5"].
List<String> _singleVerses(String passage) {
  final m = _refPattern.firstMatch(passage)!;
  final from = int.parse(m.group(3)!);
  final to = int.parse(m.group(4) ?? m.group(3)!);
  return [for (var v = from; v <= to; v++) '${m.group(1)} ${m.group(2)}:$v'];
}

Future<Archive> _fetchZip(Directory cache, String name) async {
  final file = File('${cache.path}/$name');
  if (!file.existsSync()) {
    stdout.writeln('  downloading $name');
    final client = HttpClient();
    final res = await (await client.getUrl(Uri.parse('https://ebible.org/Scriptures/$name'))).close();
    if (res.statusCode != 200) throw HttpException('$name → ${res.statusCode}');
    await res.pipe(file.openWrite());
    client.close();
  }
  return ZipDecoder().decodeBytes(file.readAsBytesSync());
}

/// VPL lines look like: "MAT 6:34 verse text"
Map<String, String> _parseVpl(String body) {
  final map = <String, String>{};
  final line = RegExp(r'^﻿?([1-3]?[A-Z]{2,3} \d+:\d+) (.*)$');
  for (final l in const LineSplitter().convert(body)) {
    final m = line.firstMatch(l);
    if (m != null) map[m.group(1)!] = m.group(2)!.trim();
  }
  return map;
}

/// Picks a display name from USFM headers: \toc2 (short) unless it is an
/// abbreviation ("மத்", "മത്താ.") of \toc1, in which case \toc1 is used.
String? _bookName(String usfm) {
  String? tag(String t) =>
      RegExp('^\\\\$t (.+)\$', multiLine: true).firstMatch(usfm)?.group(1)?.trim();
  final long = tag('toc1') ?? tag('h');
  final short = tag('toc2');
  if (short == null) return long;
  if (long == null) return short;
  final truncated = short.endsWith('.') ||
      (long.length > short.length && long.startsWith(short) && long[short.length] != ' ');
  return truncated ? long : short;
}

const _newTestament = {
  'MAT', 'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO', 'GAL', 'EPH', 'PHP', 'COL', '1TH', '2TH',
  '1TI', '2TI', 'TIT', 'PHM', 'HEB', 'JAS', '1PE', '2PE', '1JN', '2JN', '3JN', 'JUD', 'REV',
};

/// USFM lines that are not verse text: headings, titles, book identification.
final _nonText = RegExp(r'^\\(id|ide|h|toc\d?|mt\d?|ms\d?|mr|s\d?|sr|r|d|sp|cl|cp|rem|usfm|sts)(\s|$)');

/// Markers whose content is not verse text: footnotes, cross references,
/// alternate numbers, figures. Skipped up to their closing marker.
const _notes = {'f', 'fe', 'ef', 'x', 'ex', 'ca', 'va', 'vp', 'fig', 'rq'};

/// One book's verses from USFM, each as text runs flagged true where Jesus
/// speaks (inside \wj … \wj*). Keys look like "MAT 4:19".
Map<String, List<(String, bool)>> _usfmSegments(String book, String usfm) {
  // Word attributes go: \w grace|strong="G5485"\w* → grace.
  final body = const LineSplitter()
      .convert(usfm.replaceAll(RegExp(r'\|[^\\|]*(?=\\\+?w\*)'), ''))
      .where((l) => !_nonText.hasMatch(l.trimLeft()))
      .join('\n');
  // \c 4 · \v 19 (or bridged \v 4-5) · closing \wj* · opening \wj (eats one space).
  final marker = RegExp(r'\\(?:([cv]) (\d+)(?:-\d+)? ?|\+?([a-z]+\d*)\*|\+?([a-z]+\d*) ?)');
  final out = <String, List<(String, bool)>>{};
  var chapter = '0';
  List<(String, bool)>? verse;
  var wj = false;
  String? note;
  var pos = 0;
  void text(String s) {
    if (note == null && s.isNotEmpty) verse?.add((s, wj));
  }

  for (final m in marker.allMatches(body)) {
    text(body.substring(pos, m.start));
    pos = m.end;
    final closing = m.group(3), opening = m.group(4);
    if (note != null) {
      if (closing == note) note = null;
    } else if (m.group(1) != null) {
      // Words of Jesus never run on past a verse; a \wj left open is a typo in the source.
      wj = false;
      if (m.group(1) == 'c') {
        chapter = m.group(2)!;
        verse = null;
      } else {
        verse = out['$book $chapter:${m.group(2)}'] = [];
      }
    } else if (opening != null && _notes.contains(opening)) {
      note = opening;
    } else if (opening == 'wj') {
      wj = true;
    } else if (closing == 'wj') {
      wj = false;
    } else if (opening != null && verse != null) {
      // A paragraph or poetry line inside a verse still separates words.
      text(' ');
    }
  }
  text(body.substring(pos));
  return out;
}

/// The [start, end) ranges of [target] (a verse's cleaned text) that the
/// USFM [segments] mark as Jesus speaking, or null if the two texts differ
/// too much to tell.
List<List<int>>? _speechSpans(List<(String, bool)> segments, String target) {
  // Clean the USFM text the way _clean does, keeping each character's flag.
  final chars = <String>[];
  final flags = <bool>[];
  var space = false;
  for (final (s, wj) in segments) {
    for (final ch in s.split('')) {
      if ('[]¶'.contains(ch)) continue;
      if (ch.trim().isEmpty) {
        space = true;
        continue;
      }
      if (space && chars.isNotEmpty) {
        chars.add(' ');
        flags.add(wj);
      }
      space = false;
      chars.add(ch);
      flags.add(wj);
    }
  }

  List<bool> mask;
  if (chars.join() == target) {
    mask = flags;
  } else {
    // The texts differ a little (punctuation, spacing): line them up with a
    // longest-common-subsequence and carry the flags across.
    final t = target.split('');
    final n = chars.length, k = t.length;
    final lcs = List.generate(n + 1, (_) => List.filled(k + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = k - 1; j >= 0; j--) {
        lcs[i][j] = chars[i] == t[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1]);
      }
    }
    if (lcs[0][0] < 0.9 * max(n, k)) return null;
    final matched = List<bool?>.filled(k, null);
    for (var i = 0, j = 0; i < n && j < k;) {
      if (chars[i] == t[j]) {
        matched[j++] = flags[i++];
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    // A character only the target has is His if the characters around it are.
    mask = List.filled(k, false);
    for (var j = 0; j < k; j++) {
      if (matched[j] case final f?) {
        mask[j] = f;
      } else {
        final before = matched.sublist(0, j).lastWhere((f) => f != null, orElse: () => false)!;
        final after = matched.sublist(j + 1).firstWhere((f) => f != null, orElse: () => false)!;
        mask[j] = before && after;
      }
    }
  }

  final spans = <List<int>>[];
  for (var i = 0; i < target.length;) {
    if (!mask[i]) {
      i++;
      continue;
    }
    var end = i;
    while (end < target.length && mask[end]) {
      end++;
    }
    var s = i, e = end;
    while (s < e && target[s] == ' ') {
      s++;
    }
    while (e > s && target[e - 1] == ' ') {
      e--;
    }
    spans.addAll(_endAtClosingQuote(target, s, e));
    i = end;
  }
  return spans;
}

/// A span that opens with “ ends at its matching ”. Some sources close \wj
/// late, after the narration that follows His words ("…” and they parted his
/// garments"); the quotation marks show where He stopped speaking.
List<List<int>> _endAtClosingQuote(String text, int start, int end) {
  if (start >= end) return [];
  if (text[start] != '“') return [[start, end]];
  var depth = 0;
  for (var i = start; i < end; i++) {
    if (text[i] == '“') depth++;
    if (text[i] == '”' && --depth == 0 && i + 1 < end) {
      final next = text.indexOf('“', i + 1);
      _quoteTrims++;
      return [
        [start, i + 1],
        if (next != -1 && next < end) ..._endAtClosingQuote(text, next, end),
      ];
    }
  }
  return [[start, end]];
}

var _quoteTrims = 0;

/// Strips KJV italics brackets and pilcrows; normalises whitespace.
String _clean(String s) => s
    .replaceAll(RegExp(r'[\[\]¶]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
