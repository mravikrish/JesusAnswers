import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/languages.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'data/models/answer.dart';
import 'features/answer/answer_screen.dart';
import 'features/bible/bible_screen.dart';
import 'features/circles/circle_show_screen.dart';
import 'features/circles/circles_screen.dart';
import 'features/daily_word/daily_word_screen.dart';
import 'features/feedback/feedback_screen.dart';
import 'features/home/home_screen.dart';
import 'features/jesus_words/jesus_words_screen.dart';
import 'features/jesus_words/speak_screen.dart';
import 'features/journey/journey_screen.dart';
import 'features/mood/mood_screen.dart';
import 'features/peace/peace_now_screen.dart';
import 'features/pictures/pictures_screen.dart';
import 'features/player/player_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/prayer/prayers_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/question/question_screen.dart';
import 'features/stories/stories_screen.dart';
import 'features/talk/listening_screen.dart';
import 'features/talk/processing_screen.dart';
import 'features/welcome/language_screen.dart';
import 'features/welcome/onboarding_screen.dart';
import 'features/welcome/sign_in_screen.dart';
import 'features/welcome/splash_screen.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // Splash → language → welcome pages → Home on first launch; splash → Home after that.
    // Name and number are optional, set later in Profile.
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const LanguageScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/word', builder: (_, _) => const DailyWordScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/pray', builder: (_, _) => const PrayerScreen())]),
          StatefulShellBranch(routes: [GoRoute(
              path: '/journey',
              // /journey?show=prayers: straight to the prayers made for them (from Pray's "My prayers").
              builder: (_, state) => JourneyScreen(
                key: ValueKey(state.uri.query),
                prayersOnly: state.uri.queryParameters['show'] == 'prayers',
              ),
            ),]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/mood', builder: (_, _) => const MoodScreen()),
      GoRoute(path: '/listen', builder: (_, _) => const ListeningScreen()),
      GoRoute(path: '/peace', builder: (_, _) => const PeaceNowScreen()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
      GoRoute(path: '/pictures', builder: (_, _) => const PicturesScreen()),
      GoRoute(
        path: '/pictures/:index',
        builder: (_, state) => PictureViewerScreen(index: int.tryParse(state.pathParameters['index']!) ?? 0),
      ),
      // 'jesus', 'stories' or 'books', each as WhatsApp status pictures.
      GoRoute(
        path: '/pictures/:collection/:index',
        builder: (_, state) => PictureViewerScreen(
          collection: state.pathParameters['collection']!,
          index: int.tryParse(state.pathParameters['index']!) ?? 0,
        ),
      ),
      GoRoute(path: '/prayers', builder: (_, _) => const PrayersScreen()),
      // ?for=1 opens it to pray for someone else, by name.
      GoRoute(
        path: '/prayers/:id',
        builder: (_, state) => PrayerReadScreen(
          id: state.pathParameters['id']!,
          forSomeone: state.uri.queryParameters['for'] == '1',
          along: state.uri.queryParameters['along'] == '1',
        ),
      ),
      GoRoute(path: '/circles', builder: (_, _) => const CirclesScreen()),
      GoRoute(path: '/circles/:code', builder: (_, state) => CircleScreen(code: state.pathParameters['code']!)),
      // The invite on the church's screen: ?name= is the circle's name.
      GoRoute(
        path: '/circles/:code/screen',
        builder: (_, state) => CircleShowScreen(
          code: state.pathParameters['code']!,
          name: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      // jesusanswers://app/join/K7P3MX, from the QR code on that screen: Join, with the code filled in.
      // Someone who hasn't set up the app yet does that first.
      GoRoute(
        path: '/join/:code',
        redirect: (_, _) {
          final s = ref.read(settingsProvider);
          return s.languageChosen && s.onboarded ? null : '/splash';
        },
        builder: (_, state) => CirclesScreen(joinCode: state.pathParameters['code']),
      ),
      GoRoute(path: '/question', builder: (_, _) => const QuestionScreen()),
      GoRoute(path: '/stories', builder: (_, _) => const StoriesScreen()),
      GoRoute(path: '/stories/:id', builder: (_, state) => StoryScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/jesus', builder: (_, _) => const JesusWordsScreen()),
      // Hear Him speak: ?book=MAT&chapter=5 for His words in a chapter; none for the famous sayings.
      GoRoute(
        path: '/jesus/speak',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          final chapter = int.tryParse(q['chapter'] ?? '');
          return SpeakScreen(chapter: q['book'] == null || chapter == null ? null : (q['book']!, chapter));
        },
      ),
      GoRoute(path: '/bible', builder: (_, _) => const BibleScreen()),
      // ?words=1 opens it from Words of Jesus; ?v=19 marks a verse.
      GoRoute(
        path: '/bible/:book/:chapter',
        builder: (_, state) => ChapterScreen(
          book: state.pathParameters['book']!,
          chapter: int.tryParse(state.pathParameters['chapter']!) ?? 1,
          words: state.uri.queryParameters['words'] == '1',
          highlight: int.tryParse(state.uri.queryParameters['v'] ?? ''),
        ),
      ),
      GoRoute(path: '/player', builder: (_, state) => PlayerScreen(args: state.extra! as PlayerArgs)),
      GoRoute(
        path: '/processing',
        builder: (_, state) => ProcessingScreen(request: state.extra! as AnswerRequest),
      ),
      GoRoute(
        path: '/answer/:id',
        builder: (_, state) => AnswerScreen(
          id: state.pathParameters['id']!,
          autoplay: state.uri.queryParameters['speak'] == '1',
        ),
      ),
    ],
  );
});

class JesusAnswersApp extends ConsumerWidget {
  const JesusAnswersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final textScale = ref.watch(settingsProvider.select((s) => s.textScale));
    ref.watch(reminderSyncProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: [for (final l in appLanguages) l.locale],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      // The Profile text size multiplies the phone's own font size setting.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale)),
          child: child!,
        );
      },
    );
  }
}
