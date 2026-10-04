import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../core/widgets/playback_controls.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/tts_service.dart';

/// Peace Now — guided breathing with one verse. No clutter, no scrolling.
class PeaceNowScreen extends ConsumerStatefulWidget {
  const PeaceNowScreen({super.key});

  @override
  ConsumerState<PeaceNowScreen> createState() => _PeaceNowScreenState();
}

class _PeaceNowScreenState extends ConsumerState<PeaceNowScreen> with SingleTickerProviderStateMixin {
  static const _inhale = 4, _exhale = 6;
  late final _breath = AnimationController(vsync: this, duration: const Duration(seconds: _inhale + _exhale))
    ..repeat();
  late final _tts = ref.read(ttsProvider);

  @override
  void initState() {
    super.initState();
    // Take the voice now: ref can't be used once the screen is closing, and without
    // this the voice kept playing after leaving. Warming it up also starts Listen sooner.
    _tts.warmUp(ref.read(settingsProvider).language);
  }

  @override
  void dispose() {
    _breath.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final verse = ref.watch(verseProvider('1PE 5:7')).value;
    const split = _inhale / (_inhale + _exhale);

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                Text(l.peaceNow, style: AppText.serif(34, color: Colors.white)),
                Text(l.peaceSubtitle,
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                const Spacer(),
                AnimatedBuilder(
                  animation: _breath,
                  builder: (_, _) {
                    final t = _breath.value;
                    final inhaling = t < split;
                    final p = inhaling ? t / split : 1 - (t - split) / (1 - split);
                    final scale = 0.7 + 0.3 * Curves.easeInOut.transform(p);
                    return SizedBox.square(
                      dimension: 230,
                      child: Center(
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 230,
                            height: 230,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.lavender.withValues(alpha: 0.8), width: 2),
                              gradient: RadialGradient(colors: [
                                AppColors.lavender.withValues(alpha: 0.35),
                                AppColors.navy.withValues(alpha: 0.1),
                              ]),
                              boxShadow: [
                                BoxShadow(color: AppColors.lavender.withValues(alpha: 0.35), blurRadius: 50),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(inhaling ? l.breatheIn : l.breatheOut,
                                    style: AppText.serif(26, color: Colors.white)),
                                Text(l.seconds(inhaling ? _inhale : _exhale),
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                if (verse != null) GlassCard(child: VerseQuote(verse: verse, dark: true, center: true)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: _tts.playback,
                        builder: (_, playback, _) {
                          final playing = playback != Playback.idle;
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              minimumSize: const Size.fromHeight(50),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: verse == null
                                ? null
                                : () => playing
                                    ? _tts.stop()
                                    : readAloud(
                                        context,
                                        [verse.text, verse.reference, l.genericEncouragement],
                                        ref.read(settingsProvider).language,
                                      ),
                            icon: Icon(playing ? Icons.stop_rounded : Icons.volume_up_rounded),
                            label: Text(playing ? l.stop : l.listen),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: () => context.go('/pray'),
                        icon: const Icon(Icons.volunteer_activism_rounded),
                        label: Text(l.prayWithMe, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
