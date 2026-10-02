import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/verse.dart';

class _IndexEntry {
  const _IndexEntry(this.ref, this.themes);
  final String ref;
  final List<String> themes;
}

class _Translation {
  const _Translation(this.abbrev, this.attribution, this.books, this.verses);
  final String abbrev;
  final String attribution;
  final Map<String, String> books;
  final Map<String, String> verses;
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
    );
  }

  Future<String> attribution(String lang) async => (await _load(lang)).attribution;

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

  /// 0 (Jan 1) … 364 (Dec 31).
  static int dayIndex(DateTime day) {
    final date = (day.month == 2 && day.day == 29) ? 28 : day.day;
    return DateTime.utc(2023, day.month, date).difference(DateTime.utc(2023)).inDays;
  }
}
