import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/languages.dart';
import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/night_background.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/tts_service.dart';

/// One verse to read aloud in the player.
class PlayerTrack {
  const PlayerTrack({required this.verse, required this.parts, this.caption});
  final Verse verse;

  /// What is read aloud, in order (usually the reference, then the verse).
  final List<String> parts;

  /// Shown under the reference, e.g. the date of a Daily Word.
  final String? caption;
}

class PlayerArgs {
  const PlayerArgs({required this.tracks, required this.lang, this.start = 0});
  final List<PlayerTrack> tracks;
  final AppLanguage lang;
  final int start;
}

/// Full-screen listening: one verse large and still, with a progress bar
/// that can be dragged, and previous / next to move between verses.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.args});
  final PlayerArgs args;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final _tts = ref.read(ttsProvider);
  late int _i = widget.args.start.clamp(0, widget.args.tracks.length - 1);

  /// Where the thumb is while being dragged; null otherwise.
  double? _dragging;

  PlayerTrack get _track => widget.args.tracks[_i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _play() {
    if (mounted) readAloud(context, _track.parts, widget.args.lang);
  }

  void _go(int i) {
    setState(() => _i = i);
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tracks = widget.args.tracks;
    final track = _track;

    return Scaffold(
      body: NightBackground(
        warm: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        track.verse.reference,
                        textAlign: TextAlign.center,
                        style: AppText.serif(22, color: Colors.white, weight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: l.shareVerse,
                      onPressed: () => showVerseActions(context, track.verse),
                      icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
                    ),
                  ],
                ),
                if (track.caption != null)
                  Text(track.caption!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Center(
                      key: ValueKey(_i),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          children: [
                            Text(
                              '“${track.verse.text}”',
                              textAlign: TextAlign.center,
                              style: AppText.serif(30, color: Colors.white, height: 1.35),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${track.verse.reference} · ${track.verse.translation}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: _tts.progress,
                  builder: (_, progress, _) => SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.goldSoft,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white12,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _dragging ?? progress,
                      onChanged: (v) => setState(() => _dragging = v),
                      onChangeEnd: (v) {
                        _tts.seek(v);
                        setState(() => _dragging = null);
                      },
                    ),
                  ),
                ),
                if (tracks.length > 1)
                  Text(l.trackOf(_i + 1, tracks.length),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: _tts.playback,
                  builder: (_, playback, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l.previous,
                        iconSize: 36,
                        color: Colors.white,
                        disabledColor: Colors.white24,
                        onPressed: _i > 0 ? () => _go(_i - 1) : null,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      const SizedBox(width: 24),
                      IconButton.filled(
                        tooltip: playback == Playback.playing ? l.pause : l.listen,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.white,
                          fixedSize: const Size.square(76),
                          shadowColor: AppColors.gold,
                          elevation: 8,
                        ),
                        iconSize: 40,
                        onPressed: switch (playback) {
                          Playback.idle => _play,
                          Playback.playing => _tts.pause,
                          Playback.paused => _tts.resume,
                        },
                        icon: Icon(playback == Playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        tooltip: l.next,
                        iconSize: 36,
                        color: Colors.white,
                        disabledColor: Colors.white24,
                        onPressed: _i < tracks.length - 1 ? () => _go(_i + 1) : null,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SlowerToggle(dark: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
