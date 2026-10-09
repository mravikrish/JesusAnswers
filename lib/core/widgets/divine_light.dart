import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft rays of light falling from above, with specks of light drifting
/// upward through them — the sense of a Presence in the room.
///
/// Purely decorative: wrap in [Positioned.fill] behind content. Slow on purpose
/// (one full cycle is 40 s) so it calms rather than distracts.
class DivineLight extends StatefulWidget {
  const DivineLight({
    super.key,
    this.color = AppColors.goldSoft,
    this.intensity = 1,
    this.origin = const Alignment(0, -1.15),
    this.still = false,
  });

  final Color color;

  /// 0–1+; lower on light backgrounds.
  final double intensity;

  /// Where the light comes from.
  final Alignment origin;

  /// Painted once, without moving: for a panel at the top of a page people read.
  final bool still;

  @override
  State<DivineLight> createState() => _DivineLightState();
}

class _DivineLightState extends State<DivineLight> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void initState() {
    super.initState();
    if (!widget.still) _t.repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.still || MediaQuery.of(context).disableAnimations) {
      return CustomPaint(painter: _LightPainter(0, widget.color, widget.intensity, widget.origin));
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, _) => CustomPaint(painter: _LightPainter(_t.value, widget.color, widget.intensity, widget.origin)),
      ),
    );
  }
}

class _LightPainter extends CustomPainter {
  _LightPainter(this.t, this.color, this.intensity, this.origin);
  final double t;
  final Color color;
  final double intensity;
  final Alignment origin;

  static final _motes = List.generate(28, (i) {
    final r = math.Random(i * 7919 + 17);
    return (x: r.nextDouble(), y: r.nextDouble(), size: 0.8 + r.nextDouble() * 2.2, speed: 0.4 + r.nextDouble(), phase: r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final o = origin.alongSize(size);
    final twoPi = math.pi * 2;

    // Glow at the source.
    canvas.drawCircle(
      o,
      w * 0.9,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.28 * intensity),
          color.withValues(alpha: 0.06 * intensity),
          color.withValues(alpha: 0),
        ], stops: const [0, 0.45, 1])
            .createShader(Rect.fromCircle(center: o, radius: w * 0.9)),
    );

    // Rays: thin wedges fanning downward, each breathing at its own pace.
    final reach = h * 1.4;
    const rays = 11;
    for (var i = 0; i < rays; i++) {
      final base = math.pi / 2 + (i - (rays - 1) / 2) * 0.13;
      final sway = math.sin(twoPi * t + i * 1.7) * 0.025;
      final angle = base + sway;
      final spread = 0.025 + (i % 3) * 0.012;
      final alpha = (0.05 + 0.05 * (0.5 + 0.5 * math.sin(twoPi * t * 2 + i * 2.3))) * intensity;
      final p1 = o + Offset(math.cos(angle - spread), math.sin(angle - spread)) * reach;
      final p2 = o + Offset(math.cos(angle + spread), math.sin(angle + spread)) * reach;
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, o.dy, w, reach * 0.8)),
      );
    }

    // Specks of light drifting slowly upward and twinkling.
    for (final m in _motes) {
      final y = ((m.y - t * m.speed * 2) % 1) * h;
      final x = m.x * w + math.sin(twoPi * (t * 3 + m.phase)) * 8;
      final twinkle = 0.5 + 0.5 * math.sin(twoPi * (t * 6 + m.phase));
      // Fade out toward the bottom so they rise "from" the light.
      final fade = (1 - y / h).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        m.size,
        Paint()
          ..color = color.withValues(alpha: (0.15 + 0.45 * twinkle) * fade * intensity.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.t != t || old.color != color || old.intensity != intensity;
}
