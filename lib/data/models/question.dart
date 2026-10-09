/// A daily Bible question, in the reader's language.
class BibleQuestion {
  const BibleQuestion({
    required this.id,
    required this.passage,
    required this.question,
    required this.options,
    required this.about,
    required this.think,
    this.story,
  });

  final String id;

  /// Where the Bible answers it ("DAN 6:16-23"), shown from the reader's own Bible once they answer.
  final String passage;
  final String question;

  /// Four options, the right one first (shown shuffled).
  final List<String> options;

  /// What happened, in plain words: who, where and why — so the passage makes sense.
  final String about;

  /// A thought to take into the day.
  final String think;

  /// The app's Bible story that tells it, if any.
  final String? story;

  String get answer => options.first;
}
