import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../data/bible/bible_repository.dart';
import '../../data/models/answer.dart';
import '../../data/models/mood.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import 'safety.dart';
import 'theme_classifier.dart';

/// Question → Understanding → Scripture → Encouragement → Prayer.
abstract interface class AnswerService {
  Future<Answer> answer(AnswerRequest request);
}

const _uuid = Uuid();

/// Works fully offline. Picks real verses by theme and wraps them in
/// pre-written encouragement — personalised English text per theme, and a
/// warm general message in every other language. Used when no backend is
/// configured, and as the fallback when the backend is unreachable.
class LocalAnswerService implements AnswerService {
  LocalAnswerService(this.bible);

  final BibleRepository bible;

  @override
  Future<Answer> answer(AnswerRequest r) async {
    final crisis = Safety.isCrisis(r.question);
    final themes = crisis
        ? const ['crisis', 'hurt', 'loneliness']
        : {...?Mood.byName(r.mood)?.themes, if (r.question.isNotEmpty) ...ThemeClassifier.classify(r.question)}
            .toList();
    final verses = await bible.versesFor(themes, r.lang, seed: r.question.hashCode);
    final l = lookupAppLocalizations(Locale(r.lang));
    final english = r.lang == 'en';
    final primary = themes.firstWhere(_english.containsKey, orElse: () => 'peace');

    return Answer(
      id: _uuid.v4(),
      kind: r.kind,
      question: r.question,
      lang: r.lang,
      mood: r.mood,
      themes: themes,
      verses: verses,
      encouragement: english ? _english[primary]!.$1 : l.genericEncouragement,
      prayer: english ? _prayer(_english[primary]!.$2) : l.genericPrayer,
      createdAt: DateTime.now(),
      crisis: crisis,
    );
  }

  static String _prayer(String need) =>
      'Lord Jesus, I bring this before You. $need '
      'Help me to trust You, even when I cannot see the way ahead. '
      'Thank You for always being with me. Amen.';

  /// theme → (encouragement, prayer petition)
  static const _english = <String, (String, String)>{
    'crisis': (
      'What you are carrying right now is very heavy, and you should not have to carry it alone. '
          'Please reach out to someone today — God often sends His help through people.',
      'Hold me close in this dark moment, and bring people around me who can help.',
    ),
    'anxiety': (
      "You don't have to carry the weight of tomorrow today. God already knows your situation, "
          'and He is with you in it. Take one step at a time and trust Him with what you cannot control.',
      'Calm my anxious thoughts and give me Your peace, one day at a time.',
    ),
    'stress': (
      'You were never meant to hold everything together on your own. Pause, breathe, and hand this '
          'burden to God. He cares for you more than you know.',
      'Lift the weight I am carrying, and give me rest and wisdom for today.',
    ),
    'fear': (
      'Fear speaks loudly, but it does not have the final word. God is with you, and He goes before you '
          'into whatever you are facing.',
      'Replace my fear with courage, and remind me that You are with me.',
    ),
    'work': (
      'Your worth is not measured by your job or your success. Do your work faithfully, and leave the '
          'outcome in God’s hands — He is providing for you even now.',
      'Guide me in my work, open the right doors, and give me peace about my provision.',
    ),
    'finances': (
      'Money worries can keep us up at night, but God sees every need you have. Take the next wise step, '
          'and trust Him to supply what you cannot.',
      'Provide for my needs, give me wisdom with what I have, and free me from worry.',
    ),
    'future': (
      'This moment may feel uncertain, but your present situation does not define your future. '
          'God holds tomorrow, so you can rest today.',
      'I place my future in Your hands. Lead me, step by step.',
    ),
    'sad': (
      'It is okay to feel sad. God is close to you in this, and your tears are not unseen. '
          'This season will not last forever.',
      'Comfort my heart, and let Your joy return to me in time.',
    ),
    'grief': (
      'Grief is the cost of love, and God grieves with you. Let yourself mourn; you will be comforted, '
          'and you do not walk this valley alone.',
      'Comfort me in my loss, and hold the one I love in Your care.',
    ),
    'hurt': (
      'What happened to you matters to God. He is near to the brokenhearted, and He can heal wounds '
          'that no one else can see.',
      'Heal the hurt in my heart, and help me, in time, to walk free from it.',
    ),
    'loneliness': (
      'Even when it feels like no one understands, you are not alone. God has promised never to leave '
          'you nor forsake you.',
      'Be near to me in my loneliness, and bring true friendship into my life.',
    ),
    'anger': (
      'Your anger is real, but it does not have to control you. Take a breath before you speak, and let '
          'God show you a better way through this.',
      'Calm the anger in me, and give me patience and a gentle answer.',
    ),
    'forgiveness': (
      'No mistake puts you beyond God’s mercy. Bring it to Him honestly — He is faithful to forgive and '
          'to make you new.',
      'Forgive me, cleanse my heart, and help me to forgive others as You forgive me.',
    ),
    'family': (
      'Families are precious and sometimes painful. Love patiently, listen first, and trust God to work '
          'in hearts where you cannot.',
      'Bless my family. Bring peace, understanding and love into our home.',
    ),
    'marriage': (
      'Love is patient and kind, even when it is hard. Ask God for a soft heart and a gentle word, '
          'and take one small step toward each other.',
      'Strengthen our marriage with patience, kindness and forgiveness.',
    ),
    'children': (
      'Your children are a gift from God, and He loves them even more than you do. Keep guiding them '
          'with love, and entrust them to Him.',
      'Protect and guide my children, and give me wisdom as a parent.',
    ),
    'healing': (
      'God sees your pain and your body’s struggle. Keep seeking good care, and let Him carry you '
          'through each day of this journey.',
      'Bring healing, give strength to my body, and peace to my mind.',
    ),
    'temptation': (
      'You are not the only one who struggles, and you are not powerless. God always makes a way out — '
          'take it today, and reach out to someone you trust.',
      'Give me strength to resist, and show me the way of escape.',
    ),
    'failure': (
      'Falling down is not the end of your story. God’s mercies are new every morning, and He can '
          'use even this to shape your future.',
      'Lift me up from this failure, and help me begin again with You.',
    ),
    'decision': (
      'You don’t have to see the whole path to take the next step. Ask God for wisdom — He promises to '
          'give it generously — and trust Him to direct your way.',
      'Give me wisdom for this decision, and make the right path clear.',
    ),
    'lost': (
      'Feeling lost does not mean you are forgotten. God knows exactly where you are, and He will guide '
          'you one step at a time.',
      'Show me the way, and remind me of the purpose You have for me.',
    ),
    'purpose': (
      'You were made with intention and love. Your life has purpose, even in the ordinary days.',
      'Show me the good works You have prepared for me, and help me walk in them.',
    ),
    'tired': (
      'You are allowed to rest. Jesus invites the weary to come to Him — not to try harder, but to find '
          'rest for your soul.',
      'Renew my strength, and give me true rest in You.',
    ),
    'sleep': (
      'Let the day go now. You can lie down in peace, because God keeps watch through the night.',
      'Quiet my mind, and give me peaceful sleep tonight.',
    ),
    'gratitude': (
      'What a beautiful thing to give thanks! Every good gift comes from God — let your heart rejoice '
          'in His goodness today.',
      'Thank You for Your goodness and every blessing in my life.',
    ),
    'strength': (
      'When you feel weak, God’s strength is made perfect. You can keep going — not alone, but with Him.',
      'Give me strength for today, and courage for what lies ahead.',
    ),
    'hope': (
      'Hope is not lost. God is working, even when you cannot see it, and His plans for you are good.',
      'Fill me with hope, and help me hold on to Your promises.',
    ),
    'peace': (
      'Be still for a moment. You don’t have to solve everything tonight — God is with you, '
          'and His peace is greater than your worries.',
      'Fill my heart with Your peace.',
    ),
    'patience': (
      'Waiting is hard, but it is never wasted. God’s timing is perfect — keep trusting and keep doing good.',
      'Give me patience as I wait on You.',
    ),
    'faith': (
      'Even small faith in a great God is enough. Lean on Him, not on your own understanding.',
      'Strengthen my faith, and help me trust You with all my heart.',
    ),
  };
}

/// Calls the JesusAnswers backend (Spring Boot + LLM).
///
/// Contract — POST {baseUrl}/v1/answers
///   request:  { "question", "lang", "mood"?, "kind": "question"|"prayer" }
///   response: { "themes": [..], "verseRefs": ["MAT 6:34", ..],
///               "encouragement", "prayer", "crisis": bool }
///
/// The server only *chooses* verse references (from the same index the app
/// bundles); the app renders verse text from its own corpus, so a reference
/// the corpus doesn't contain is simply dropped — Scripture can't be invented.
class RemoteAnswerService implements AnswerService {
  RemoteAnswerService(this.baseUrl, this.bible, this.fallback, {http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final BibleRepository bible;
  final AnswerService fallback;
  final http.Client _client;

  @override
  Future<Answer> answer(AnswerRequest r) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/v1/answers'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'question': r.question, 'lang': r.lang, 'mood': r.mood, 'kind': r.kind.name}),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return await fallback.answer(r);

      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final themes = (j['themes'] as List? ?? []).cast<String>();
      var verses = <Verse>[
        for (final ref in (j['verseRefs'] as List? ?? []).cast<String>()) ?await bible.verse(ref, r.lang),
      ];
      if (verses.isEmpty) verses = await bible.versesFor(themes, r.lang, seed: r.question.hashCode);

      return Answer(
        id: _uuid.v4(),
        kind: r.kind,
        question: r.question,
        lang: r.lang,
        mood: r.mood,
        themes: themes,
        verses: verses,
        encouragement: j['encouragement'] as String,
        prayer: j['prayer'] as String,
        createdAt: DateTime.now(),
        crisis: (j['crisis'] as bool? ?? false) || Safety.isCrisis(r.question),
      );
    } catch (_) {
      return fallback.answer(r);
    }
  }
}
