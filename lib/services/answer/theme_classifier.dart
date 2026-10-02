/// Lightweight keyword classifier used offline. The backend LLM replaces this
/// with real understanding (and handles every language); this only needs to
/// be good enough to pick sensible verses without a network.
abstract final class ThemeClassifier {
  static const _keywords = <String, List<String>>{
    'anxiety': ['worry', 'worried', 'anxious', 'anxiety', 'nervous', 'overthink', 'panic', 'tension'],
    'stress': ['stress', 'pressure', 'overwhelm', 'burden', 'too much'],
    'fear': ['afraid', 'fear', 'scared', 'terrified', 'frightened'],
    'work': ['job', 'work', 'boss', 'office', 'career', 'interview', 'business', 'colleague', 'promotion'],
    'finances': ['money', 'debt', 'loan', 'financ', 'bills', 'rent', 'salary', 'afford', 'emi', 'lost my job'],
    'future': ['future', 'tomorrow', 'uncertain', 'what will happen', 'lost my job'],
    'sad': ['sad', 'depress', 'feeling down', 'cry', 'unhappy', 'feeling low'],
    'grief': ['died', 'death', 'passed away', 'grief', 'funeral', 'mourn', 'miss my'],
    'hurt': ['hurt', 'betray', 'heartbroken', 'broken heart', 'rejected', 'cheated', 'abuse'],
    'loneliness': ['lonely', 'alone', 'no one', 'nobody', 'isolated', 'abandoned'],
    'anger': ['angry', 'anger', 'furious', 'hate', 'rage', 'frustrat', 'irritat'],
    'forgiveness': ['forgive', 'guilt', 'regret', 'ashamed', 'shame', 'my sins', 'sinned'],
    'family': ['family', 'parents', 'mother', 'father', 'brother', 'sister', 'relatives', 'in-law'],
    'marriage': ['marriage', 'husband', 'wife', 'spouse', 'married', 'divorce', 'relationship'],
    'children': ['child', 'children', 'kids', 'son', 'daughter', 'baby'],
    'healing': ['sick', 'illness', 'disease', 'hospital', 'cancer', 'pain', 'health', 'surgery', 'heal'],
    'temptation': ['tempt', 'addict', 'porn', 'alcohol', 'drinking', 'smoking', 'gambling'],
    'failure': ['fail', 'mistake', 'exam', 'messed up', 'not good enough'],
    'decision': ['decide', 'decision', 'choose', 'choice', 'should i', 'which way'],
    'lost': ['lost', 'direction', 'confused', "don't know what to do"],
    'purpose': ['purpose', 'meaning', 'calling', 'why am i'],
    'tired': ['tired', 'exhaust', 'weary', 'burnt out', 'burnout', 'drained'],
    'sleep': ['sleep', 'insomnia', 'tonight', 'at night'],
    'gratitude': ['thank', 'grateful', 'blessed', 'happy', 'joy'],
    'strength': ['strength', 'weak', 'give up', "can't go on", 'keep going'],
    'hope': ['hope', 'hopeless'],
    'peace': ['peace', 'calm', 'restless'],
    'patience': ['wait', 'patien', 'delay'],
    'faith': ['faith', 'doubt', 'believe', 'trust god'],
  };

  static const fallback = ['peace', 'hope', 'faith'];

  /// Each keyword must start at a word boundary ("sin" ≠ "since"); a keyword
  /// may be a stem ("financ" → "financial").
  static final _patterns = {
    for (final e in _keywords.entries)
      e.key: [for (final w in e.value) RegExp(r'\b' + RegExp.escape(w), caseSensitive: false)],
  };

  /// Themes ordered by how strongly the text matches them.
  static List<String> classify(String text) {
    final hits = <String, int>{};
    _patterns.forEach((theme, patterns) {
      final n = patterns.where((p) => p.hasMatch(text)).length;
      if (n > 0) hits[theme] = n;
    });
    final ranked = hits.keys.toList()..sort((a, b) => hits[b]!.compareTo(hits[a]!));
    return ranked.isEmpty ? fallback : ranked;
  }
}
