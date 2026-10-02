import '../../l10n/app_localizations.dart';
import 'answer.dart';

/// A handful of broad topics for filtering My Journey, each grouping the
/// finer Scripture themes stored with every entry (tool/bible/themes.json).
enum Topic {
  worry(['anxiety', 'stress', 'fear', 'future']),
  work(['work', 'finances']),
  family(['family', 'marriage', 'children']),
  sorrow(['sad', 'grief', 'hurt', 'loneliness']),
  health(['healing', 'tired', 'sleep']),
  guidance(['decision', 'lost', 'purpose', 'failure']),
  forgiveness(['forgiveness', 'temptation', 'anger']),
  faith(['faith', 'hope', 'peace', 'strength', 'patience', 'gratitude', 'morning']);

  const Topic(this.themes);
  final List<String> themes;

  bool matches(Answer a) => a.themes.any(themes.contains);

  String label(AppLocalizations l) => switch (this) {
        worry => l.topicWorry,
        work => l.topicWork,
        family => l.topicFamily,
        sorrow => l.topicSorrow,
        health => l.topicHealth,
        guidance => l.topicGuidance,
        forgiveness => l.topicForgiveness,
        faith => l.topicFaith,
      };
}
