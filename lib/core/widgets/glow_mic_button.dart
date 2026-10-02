import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's visual signature: a softly breathing golden microphone orb.
/// [level] (0–1) makes the rings swell with the speaker's voice.
class GlowMicButton extends StatefulWidget {
  const GlowMicButton({
    super.key,
    required this.onTap,
    this.size = 150,
    this.level = 0,
    this.icon = Icons.mic_rounded,
    this.color = AppColors.gold,
    this.image,
    this.imageFocus = const Alignment(0, -0.4),
  });

  final VoidCallback? onTap;
  final double size;
  final double level;
  final IconData icon;
  final Color color;

  /// Fills the orb instead of the icon (e.g. a painting of Jesus while listening).
  final ImageProvider? image;
  final Alignment imageFocus;

  @override
  State<GlowMicButton> createState() => _GlowMicButtonState();
}

class _GlowMicButtonState extends State<GlowMicButton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: s * 1.6,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final swell = 1 + widget.level.clamp(0, 1) * 0.18;
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++) _ring(s, (_pulse.value + i / 3) % 1, swell),
                  Transform.scale(
                    scale: swell,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(widget.color, Colors.white, 0.35)!,
                            widget.color,
                            Color.lerp(widget.color, Colors.black, 0.25)!,
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.55),
                            blurRadius: s * 0.35,
                            spreadRadius: s * 0.02,
                          ),
                        ],
                      ),
                      child: widget.image == null
                          ? Icon(widget.icon, size: s * 0.4, color: Colors.white)
                          : Container(
                              margin: EdgeInsets.all(s * 0.03),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(image: widget.image!, fit: BoxFit.cover, alignment: widget.imageFocus),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _ring(double s, double t, double swell) {
    final eased = Curves.easeOut.transform(t);
    return Opacity(
      opacity: (1 - eased) * 0.5,
      child: Container(
        width: s * (1 + eased * 0.55) * swell,
        height: s * (1 + eased * 0.55) * swell,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color, width: math.max(1, 3 * (1 - eased))),
        ),
      ),
    );
  }
}
