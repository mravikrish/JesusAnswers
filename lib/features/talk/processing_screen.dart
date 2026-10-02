import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/answer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// "Understanding your heart…" — a calm pause while the answer is prepared.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, required this.request});
  final AnswerRequest request;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _failed = false;
  Timer? _timer;
  late final _wave = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (_step < 3) setState(() => _step++);
    });
    _run();
  }

  Future<void> _run() async {
    setState(() => _failed = false);
    try {
      final results = await Future.wait([
        ref.read(answerServiceProvider).answer(widget.request),
        Future<void>.delayed(const Duration(milliseconds: 3000)),
      ]);
      final answer = results.first as Answer;
      ref.read(journeyProvider.notifier).add(answer);
      if (mounted) context.pushReplacement('/answer/${answer.id}${widget.request.spoken ? '?speak=1' : ''}');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = [l.stepAnalyzing, l.stepFinding, l.stepPreparing, l.stepPrayer];
    final painting = ref.watch(dailyPaintingProvider).value;

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                if (painting != null)
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.goldSoft, width: 2),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 4)],
                        image: DecorationImage(
                          image: AssetImage(painting.asset),
                          fit: BoxFit.cover,
                          alignment: painting.focus,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Text(l.processingTitle,
                      textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white)),
                ),
                SizedBox(
                  height: 140,
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (_, _) => CustomPaint(size: Size.infinite, painter: _WavePainter(_wave.value)),
                  ),
                ),
                for (var i = 0; i < steps.length; i++)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: i <= _step ? 1 : 0.35,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            i < _step ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: i < _step ? AppColors.goldSoft : Colors.white70,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(steps[i], style: const TextStyle(color: Colors.white, fontSize: 15))),
                        ],
                      ),
                    ),
                  ),
                if (_failed) ...[
                  const SizedBox(height: 16),
                  Text(l.errorGeneric, style: const TextStyle(color: AppColors.goldSoft)),
                  TextButton(onPressed: _run, child: const Icon(Icons.refresh_rounded, color: Colors.white)),
                ],
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    for (var k = 0; k < 4; k++) {
      final path = Path();
      final amp = 18.0 + k * 7;
      final phase = (t + k * 0.18) * 6.283;
      for (var x = 0.0; x <= size.width; x += 4) {
        final n = x / size.width;
        final envelope = 4 * n * (1 - n); // taper at the edges
        final y = mid + amp * envelope * math.sin(n * 10 + phase) * (k.isEven ? 1 : -0.7);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Color.lerp(AppColors.goldSoft, AppColors.lavender, k / 3)!.withValues(alpha: 0.7 - k * 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

