import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/languages.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'data/models/answer.dart';
import 'features/answer/answer_screen.dart';
import 'features/daily_word/daily_word_screen.dart';
import 'features/feedback/feedback_screen.dart';
import 'features/home/home_screen.dart';
import 'features/journey/journey_screen.dart';
import 'features/mood/mood_screen.dart';
import 'features/peace/peace_now_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/talk/listening_screen.dart';
import 'features/talk/processing_screen.dart';
import 'features/welcome/language_screen.dart';
import 'features/welcome/sign_in_screen.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final settings = ref.read(settingsProvider);
  return GoRouter(
    // Straight from language to Home — name and number are optional, set later in Profile.
    initialLocation: settings.languageChosen ? '/home' : '/welcome',
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const LanguageScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/word', builder: (_, _) => const DailyWordScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/pray', builder: (_, _) => const PrayerScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/journey', builder: (_, _) => const JourneyScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/mood', builder: (_, _) => const MoodScreen()),
      GoRoute(path: '/listen', builder: (_, _) => const ListeningScreen()),
      GoRoute(path: '/peace', builder: (_, _) => const PeaceNowScreen()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
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
