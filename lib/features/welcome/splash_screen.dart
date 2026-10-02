import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Every launch: a cross of light rising over the mountains, then on to
/// the language choice, the welcome pages or Home. A tap skips ahead.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final _cross = CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeOutCubic));
  late final _words = CurvedAnimation(parent: _c, curve: const Interval(0.3, 0.75, curve: Curves.easeOut));
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_next);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _next() {
    if (_left || !mounted) return;
    _left = true;
    final s = ref.read(settingsProvider);
    context.go(!s.languageChosen ? '/welcome' : (s.onboarded ? '/home' : '/onboarding'));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: NightBackground(
          warm: true,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _cross,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(_cross),
                    child: const SizedBox(width: 110, height: 150, child: CustomPaint(painter: _CrossOfLight())),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _words,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(_words),
                    child: Column(
                      children: [
                        const Wordmark(size: 46),
                        const SizedBox(height: 6),
                        Text(l.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slender golden cross with a soft halo, as if lit from within.
class _CrossOfLight extends CustomPainter {
  const _CrossOfLight();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final beam = w * 0.12;
    final armY = h * 0.3;
    final cross = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w / 2, h / 2), width: beam, height: h), Radius.circular(beam / 2)))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w / 2, armY), width: w * 0.72, height: beam), Radius.circular(beam / 2)));

    final glowCenter = Offset(w / 2, armY);
    canvas.drawCircle(
      glowCenter,
      h * 0.85,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.goldSoft.withValues(alpha: 0.55),
          AppColors.gold.withValues(alpha: 0.12),
          AppColors.gold.withValues(alpha: 0),
        ], stops: const [0, 0.4, 1])
            .createShader(Rect.fromCircle(center: glowCenter, radius: h * 0.85)),
    );
    canvas.drawPath(
      cross,
      Paint()
        ..color = AppColors.goldSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      cross,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, AppColors.goldSoft, AppColors.gold],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
