/// A Scripture passage quoted verbatim from a published translation.
class Verse {
  const Verse({
    required this.ref,
    required this.reference,
    required this.text,
    required this.translation,
    required this.lang,
    this.jesusWords = const [],
  });

  /// Language-neutral key, e.g. "MAT 6:34".
  final String ref;

  /// Localized display reference, e.g. "మత్తయి 6:34".
  final String reference;
  final String text;

  /// Translation abbreviation, e.g. "KJV" or "IRV".
  final String translation;
  final String lang;

  /// Where Jesus speaks in [text]: [start, end) character ranges, shown in red.
  final List<(int, int)> jesusWords;

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'reference': reference,
        'text': text,
        'translation': translation,
        'lang': lang,
        if (jesusWords.isNotEmpty) 'wj': [for (final (s, e) in jesusWords) [s, e]],
      };

  factory Verse.fromJson(Map<String, dynamic> j) => Verse(
        ref: j['ref'] as String,
        reference: j['reference'] as String,
        text: j['text'] as String,
        translation: j['translation'] as String,
        lang: j['lang'] as String,
        jesusWords: parseJesusWords(j['wj']),
      );
}

/// [[start, end], …] as stored in `assets/bible/<lang>.json` → ranges.
List<(int, int)> parseJesusWords(Object? json) => [
      for (final r in (json as List?) ?? const []) ((r as List)[0] as int, r[1] as int),
    ];

/// One numbered verse of a chapter or story passage.
class NumberedVerse {
  const NumberedVerse(this.number, this.text, [this.jesusWords = const []]);
  final int number;
  final String text;

  /// See [Verse.jesusWords].
  final List<(int, int)> jesusWords;

  /// Just His words, for reading aloud only what He said.
  String get spoken => [for (final (s, e) in jesusWords) text.substring(s, e)].join(' ');
}
