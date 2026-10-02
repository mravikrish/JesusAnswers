import 'verse.dart';

enum AnswerKind { question, prayer }

/// What the user brought to JesusAnswers.
class AnswerRequest {
  const AnswerRequest({
    required this.question,
    required this.lang,
    this.mood,
    this.kind = AnswerKind.question,
    this.spoken = false,
  });

  final String question;
  final String lang;

  /// A [Mood] name when the user started from the mood grid.
  final String? mood;
  final AnswerKind kind;

  /// Asked by voice — the answer is then read aloud without a tap.
  final bool spoken;
}

/// Scripture → Encouragement → Prayer, kept as one journey entry.
class Answer {
  const Answer({
    required this.id,
    required this.kind,
    required this.question,
    required this.lang,
    required this.verses,
    required this.encouragement,
    required this.prayer,
    required this.createdAt,
    this.mood,
    this.themes = const [],
    this.crisis = false,
    this.favorite = false,
  });

  final String id;
  final AnswerKind kind;
  final String question;
  final String lang;
  final String? mood;
  final List<String> themes;
  final List<Verse> verses;
  final String encouragement;
  final String prayer;
  final DateTime createdAt;

  /// The user may be at risk — show human/professional help first.
  final bool crisis;
  final bool favorite;

  Answer copyWith({bool? favorite}) => Answer(
        id: id,
        kind: kind,
        question: question,
        lang: lang,
        mood: mood,
        themes: themes,
        verses: verses,
        encouragement: encouragement,
        prayer: prayer,
        createdAt: createdAt,
        crisis: crisis,
        favorite: favorite ?? this.favorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'question': question,
        'lang': lang,
        'mood': mood,
        'themes': themes,
        'verses': [for (final v in verses) v.toJson()],
        'encouragement': encouragement,
        'prayer': prayer,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'crisis': crisis,
        'favorite': favorite,
      };

  factory Answer.fromJson(Map<String, dynamic> j) => Answer(
        id: j['id'] as String,
        kind: AnswerKind.values.byName(j['kind'] as String),
        question: j['question'] as String,
        lang: j['lang'] as String,
        mood: j['mood'] as String?,
        themes: (j['themes'] as List).cast<String>(),
        verses: [for (final v in j['verses'] as List) Verse.fromJson(v as Map<String, dynamic>)],
        encouragement: j['encouragement'] as String,
        prayer: j['prayer'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        crisis: j['crisis'] as bool? ?? false,
        favorite: j['favorite'] as bool? ?? false,
      );
}
