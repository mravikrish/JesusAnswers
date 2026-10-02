/// A Scripture passage quoted verbatim from a published translation.
class Verse {
  const Verse({
    required this.ref,
    required this.reference,
    required this.text,
    required this.translation,
    required this.lang,
  });

  /// Language-neutral key, e.g. "MAT 6:34".
  final String ref;

  /// Localized display reference, e.g. "మత్తయి 6:34".
  final String reference;
  final String text;

  /// Translation abbreviation, e.g. "KJV" or "IRV".
  final String translation;
  final String lang;

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'reference': reference,
        'text': text,
        'translation': translation,
        'lang': lang,
      };

  factory Verse.fromJson(Map<String, dynamic> j) => Verse(
        ref: j['ref'] as String,
        reference: j['reference'] as String,
        text: j['text'] as String,
        translation: j['translation'] as String,
        lang: j['lang'] as String,
      );
}
