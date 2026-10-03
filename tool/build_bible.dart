// Builds assets/bible/<lang>.json from published Bible translations.
//
// Usage:  dart run tool/build_bible.dart
//
// Verse text is copied verbatim from eBible.org distributions — never
// generated or translated by AI. Downloads are cached in .dart_tool/bible_cache.
import 'dart:convert';
import 'dart:io';

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
  final storyVerses = {
    for (final s in stories['stories'])
      for (final p in (s['passages'] as List).cast<String>()) ..._singleVerses(p),
  };
  final refs = {
    for (final v in index['verses']) v['ref'] as String,
    for (final m in daily['months']) ...(m['refs'] as List).cast<String>(),
    // Stories are shown verse by verse, so each verse of a passage is stored on its own.
    ...storyVerses,
  }.toList();
  final books = {for (final r in refs) _refPattern.firstMatch(r)!.group(1)!};
  final overrides = jsonDecode(File('tool/bible/book_name_overrides.json').readAsStringSync())
      as Map<String, dynamic>;

  final cache = Directory('.dart_tool/bible_cache')..createSync(recursive: true);
  final outDir = Directory('assets/bible')..createSync(recursive: true);
  var problems = 0;

  for (final src in sources) {
    stdout.writeln('▸ ${src.lang} (${src.ebibleId})');
    final vpl = await _fetchZip(cache, '${src.ebibleId}_vpl.zip');
    final vplFile = vpl.files.firstWhere((f) => f.name.endsWith('_vpl.txt'));
    final lines = _parseVpl(utf8.decode(vplFile.content as List<int>));

    final bookNames = <String, String>{};
    if (src.lang == 'en') {
      for (final b in books) {
        bookNames[b] = englishBooks[b]!;
      }
    } else {
      final usfm = await _fetchZip(cache, '${src.ebibleId}_usfm.zip');
      for (final f in usfm.files) {
        final m = RegExp(r'\d+-([1-3]?[A-Z]{2,3})').firstMatch(f.name);
        if (m == null || !books.contains(m.group(1))) continue;
        final name = _bookName(utf8.decode(f.content as List<int>));
        if (name != null) bookNames[m.group(1)!] = name;
      }
      final langOverrides = overrides[src.lang] as Map<String, dynamic>? ?? {};
      langOverrides.forEach((b, n) => bookNames[b] = n as String);
    }

    final verses = <String, String>{};
    for (final ref in refs) {
      final m = _refPattern.firstMatch(ref)!;
      final book = m.group(1)!, ch = m.group(2)!;
      final from = int.parse(m.group(3)!);
      final to = int.parse(m.group(4) ?? m.group(3)!);
      final parts = [
        for (var v = from; v <= to; v++) lines['${_vplCodes[book] ?? book} $ch:$v'] ?? '',
      ].where((t) => t.isNotEmpty).toList();
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
      if (parts.isNotEmpty) verses[ref] = _clean(parts.join(' '));
    }
    for (final b in books) {
      if (!bookNames.containsKey(b)) {
        problems++;
        stderr.writeln('  ! ${src.lang}: no book name for $b');
      }
    }

    final out = {
      'lang': src.lang,
      'translation': src.abbrev,
      'translationName': src.name,
      'attribution': '${src.name} (${src.abbrev}). ${src.license} Source: eBible.org/${src.ebibleId}',
      'books': bookNames,
      'verses': verses,
    };
    File('${outDir.path}/${src.lang}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
    stdout.writeln('  ${verses.length}/${refs.length} verses, ${bookNames.length} book names');
  }

  File('tool/bible/themes.json').copySync('${outDir.path}/index.json');
  File('tool/bible/daily.json').copySync('${outDir.path}/daily.json');
  File('tool/bible/stories.json').copySync('${outDir.path}/stories.json');
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

/// Strips KJV italics brackets and pilcrows; normalises whitespace.
String _clean(String s) => s
    .replaceAll(RegExp(r'[\[\]¶]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
