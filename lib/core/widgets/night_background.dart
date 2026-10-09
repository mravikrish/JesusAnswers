import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'divine_light.dart';

/// Deep midnight sky with a warm horizon and layered mountain silhouettes —
/// the signature backdrop for the immersive (dark) screens.
class NightBackground extends StatelessWidget {
  const NightBackground({super.key, required this.child, this.warm = false, this.light = true});

  final Widget child;

  /// A stronger sunrise glow at the horizon (Daily Word, Prayer).
  final bool warm;

  /// Rays of light from above (on by default).
  final bool light;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: warm
              ? const [AppColors.midnight, AppColors.navy, AppColors.dusk, AppColors.ember]
              : const [AppColors.midnight, AppColors.navy, AppColors.navyLight, AppColors.dusk],
          stops: const [0, 0.45, 0.78, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (light) const Positioned.fill(child: DivineLight()),
          const Positioned.fill(child: CustomPaint(painter: _MountainsPainter())),
          child,
        ],
      ),
    );
  }
}

/// The night sky as a panel at the top of an ivory screen, curving into the page below it: the
/// app's signature look for a page people read. Its light is still, so it doesn't pull at the eye.
/// Pair with [NightPanel.appBar] so the bar above it is part of the same sky.
class NightPanel extends StatelessWidget {
  const NightPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 30)});

  final Widget child;
  final EdgeInsets padding;

  /// An app bar in the panel's colour, with light text and status bar icons.
  static AppBar appBar({required Widget title, List<Widget>? actions, Widget? leading, PreferredSizeWidget? bottom}) =>
      AppBar(
        backgroundColor: AppColors.midnight,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: leading,
        title: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: title,
        ),
        actions: actions,
        bottom: bottom,
      );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.midnight, AppColors.navy, AppColors.navyLight],
          stops: [0, 0.6, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: DivineLight(still: true, intensity: 0.7, origin: Alignment(0, -1.3))),
          const Positioned.fill(child: CustomPaint(painter: _MountainsPainter())),
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

class _MountainsPainter extends CustomPainter {
  const _MountainsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void ridge(double base, List<double> peaks, Color color) {
      final path = Path()..moveTo(0, h);
      path.lineTo(0, h * base);
      final step = w / (peaks.length - 1);
      for (var i = 0; i < peaks.length; i++) {
        final x = i * step;
        final y = h * (base - peaks[i]);
        if (i == 0) {
          path.lineTo(x, y);
        } else {
          final px = (i - 0.5) * step;
          path.quadraticBezierTo(px, y + h * 0.02, x, y);
        }
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    ridge(0.86, [0.04, 0.09, 0.03, 0.11, 0.05, 0.08, 0.02], const Color(0x332A3A6B));
    ridge(0.92, [0.02, 0.06, 0.10, 0.04, 0.07, 0.03, 0.05], const Color(0x55101B3A));
    ridge(0.97, [0.03, 0.01, 0.05, 0.02, 0.06, 0.02, 0.04], const Color(0x880A1430));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
