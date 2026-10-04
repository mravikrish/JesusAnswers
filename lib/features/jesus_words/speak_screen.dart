import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/divine_light.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/natural_voices.dart';
import '../../services/voice/tts_service.dart';

/// The portrait that speaks: art/portrait/jesus_speaking.png, resized into the app.
const speakingPortrait = 'assets/portrait/jesus_speaking.jpg';

/// Some of His best-loved sayings, in order, for Hear Him speak from Words of Jesus.
/// KJV-numbered refs; every one carries His words in every language (tested).
const famousSayings = [
  'MAT 11:28', 'MAT 11:29', 'JHN 14:27', 'JHN 14:1', 'JHN 14:6', 'JHN 11:25', 'JHN 8:12', 'JHN 10:11',
  'MAT 5:3', 'MAT 5:4', 'MAT 5:8', 'MAT 5:9', 'MAT 6:33', 'MAT 6:34', 'MAT 7:7', 'JHN 13:34',
  'JHN 15:5', 'JHN 16:33', 'MAT 22:37', 'LUK 23:34', 'MAT 28:20', 'REV 3:20',
];

/// What Hear Him speak reads: His words in [book] [chapter], or the famous sayings when null.
final sayingsProvider = FutureProvider.family<List<Verse>, (String, int)?>((ref, chapter) async {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  final bible = ref.watch(bibleProvider);
  final refs = chapter == null
      ? famousSayings
      : [
          for (final v in await bible.chapter(chapter.$1, chapter.$2, lang))
            if (v.jesusWords.isNotEmpty) '${chapter.$1} ${chapter.$2}:${v.number}',
        ];
  return [
    for (final r in refs)
      if (await bible.fullVerse(r, lang) case final v? when v.jesusWords.isNotEmpty) v,
  ];
});

/// Hear Him speak: His portrait, gently alive, while a calm male voice reads
/// only His words — each word lighting up as it is spoken. Only Scripture is
/// ever spoken here, never anything generated.
class SpeakScreen extends ConsumerStatefulWidget {
  const SpeakScreen({super.key, this.chapter});

  /// (book, chapter) to read His words from; null for the famous sayings.
  final (String, int)? chapter;

  @override
  ConsumerState<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends ConsumerState<SpeakScreen> with TickerProviderStateMixin {
  late final _tts = ref.read(ttsProvider);

  /// A slow drift across the portrait, there and back.
  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat(reverse: true);

  /// A faint rise and fall, like breathing.
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
    ..repeat(reverse: true);

  /// The light glows while He speaks.
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  /// Index of the saying the current reading began at; the voice's part index counts from here.
  int _from = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _tts.playback.addListener(_onPlayback);
  }

  void _onPlayback() {
    if (_tts.playback.value == Playback.playing) {
      _glow.repeat(reverse: true);
    } else {
      _glow.animateTo(0, duration: const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _tts.playback.removeListener(_onPlayback);
    _tts.stop();
    _drift.dispose();
    _breath.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// Reads from saying [index] to the end.
  void _play(List<Verse> sayings, int index) {
    setState(() => _from = index.clamp(0, sayings.length - 1));
    readAloud(context, [for (final v in sayings.skip(_from)) v.spoken], ref.read(settingsProvider).language,
        role: VoiceRole.jesus);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sayings = ref.watch(sayingsProvider(widget.chapter)).value;
    if (sayings != null && sayings.isNotEmpty && !_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(sayings, 0);
      });
    }
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_drift, _breath]),
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_drift.value);
              final breath = math.sin(_breath.value * math.pi) * 0.006;
              return Transform.scale(
                scale: 1.04 + t * 0.07 + breath,
                alignment: Alignment(0.2 - t * 0.4, -0.6),
                child: child,
              );
            },
            child: Image.asset(speakingPortrait, fit: BoxFit.cover, alignment: const Alignment(0, -0.5)),
          ),
          AnimatedBuilder(
            animation: _glow,
            builder: (_, _) => IgnorePointer(child: DivineLight(intensity: 0.3 + _glow.value * 0.35)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99060C1E), Color(0x00060C1E), Color(0x00060C1E), Color(0xCC060C1E), Color(0xF5060C1E)],
                stops: [0, 0.18, 0.45, 0.7, 1],
              ),
            ),
          ),
          Positioned(
            top: top + 4,
            left: 8,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/jesus'),
                ),
                const Spacer(),
                // Plain about what this is: a painting, not footage.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(l.illustration, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: MediaQuery.paddingOf(context).bottom + 18,
            child: sayings == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
                : _Caption(sayings: sayings, from: _from, tts: _tts, onPlay: (i) => _play(sayings, i)),
          ),
        ],
      ),
    );
  }
}

/// The saying being spoken — words already said in red, the current word in
/// gold, the rest waiting — with its reference and the controls.
class _Caption extends StatelessWidget {
  const _Caption({required this.sayings, required this.from, required this.tts, required this.onPlay});
  final List<Verse> sayings;
  final int from;
  final TtsService tts;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([tts.position, tts.playback]),
        builder: (context, _) {
          final playing = tts.playback.value;
          final index = (from + tts.position.value.part).clamp(0, sayings.length - 1);
          final verse = sayings[index];
          final text = verse.spoken;
          final reading = playing != Playback.idle;
          final start = reading ? tts.position.value.offset.clamp(0, text.length) : text.length;
          final space = text.indexOf(' ', start);
          final end = space < 0 ? text.length : space;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${verse.reference} · ${verse.translation}',
                  style: const TextStyle(color: AppColors.goldSoft, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: text.substring(0, start), style: const TextStyle(color: AppColors.redLetter)),
                      TextSpan(text: text.substring(start, end), style: const TextStyle(color: AppColors.goldSoft)),
                      TextSpan(text: text.substring(end), style: TextStyle(color: Colors.white.withValues(alpha: 0.55))),
                    ]),
                    textAlign: TextAlign.center,
                    style: AppText.serif(24, color: Colors.white, weight: FontWeight.w600, height: 1.35)
                        .copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 10)]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: AppLocalizations.of(context).previous,
                    onPressed: index > 0 ? () => onPlay(index - 1) : null,
                    icon: const Icon(Icons.skip_previous_rounded, size: 32),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.midnight,
                      fixedSize: const Size.square(64),
                    ),
                    onPressed: switch (playing) {
                      Playback.playing => tts.pause,
                      Playback.paused => tts.resume,
                      Playback.idle => () => onPlay(index == sayings.length - 1 ? 0 : index),
                    },
                    icon: Icon(playing == Playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: AppLocalizations.of(context).next,
                    onPressed: index < sayings.length - 1 ? () => onPlay(index + 1) : null,
                    icon: const Icon(Icons.skip_next_rounded, size: 32),
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${index + 1} / ${sayings.length}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                  const SizedBox(width: 12),
                  const SlowerToggle(dark: true),
                ],
              ),
            ],
          );
        },
      );
}
