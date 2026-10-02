import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/divine_light.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Three welcome pages after the language choice, each over a painting:
/// what the app offers, how to ask, and that no one walks alone.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  // The Good Shepherd at sunset · The Sermon on the Mount · The Road to Emmaus.
  static const _paintings = [
    ('assets/jesus/02.jpg', Alignment(0, -0.6)),
    ('assets/jesus/12.jpg', Alignment(0.4, -0.2)),
    ('assets/jesus/07.jpg', Alignment(0.4, 0)),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).finishOnboarding();
    if (mounted) context.go('/home');
  }

  void _forward() => _page == _paintings.length - 1
      ? _finish()
      : _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = [
      (l.onboardTitle1, l.onboardBody1),
      (l.onboardTitle2, l.onboardBody2),
      (l.onboardTitle3, l.onboardBody3),
    ];
    final last = _page == _paintings.length - 1;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: _paintings.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _Page(
              painting: _paintings[i].$1,
              focus: _paintings[i].$2,
              title: text[i].$1,
              body: text[i].$2,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: TextButton(
                      onPressed: last ? null : _finish,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: Text(l.skip),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 24, 28),
                  child: Row(
                    children: [
                      for (var i = 0; i < _paintings.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      const Spacer(),
                      last
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.ink,
                                minimumSize: const Size(140, 54),
                              ),
                              onPressed: _forward,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              iconAlignment: IconAlignment.end,
                              label: Text(l.begin),
                            )
                          : IconButton.filled(
                              tooltip: l.next,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.ink,
                                fixedSize: const Size.square(58),
                              ),
                              onPressed: _forward,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.painting, required this.focus, required this.title, required this.body});
  final String painting;
  final Alignment focus;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(painting, fit: BoxFit.cover, alignment: focus),
          // Night falls over the top for the words, and over the bottom for the controls.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF00A1430), Color(0xB30A1430), Color(0x000A1430), Color(0x000A1430), Color(0xCC0A1430)],
                stops: [0, 0.3, 0.55, 0.75, 1],
              ),
            ),
          ),
          const IgnorePointer(child: DivineLight(intensity: 0.7)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 64, 28, 0),
              child: Column(
                children: [
                  Text(title, textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 14),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 16, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
