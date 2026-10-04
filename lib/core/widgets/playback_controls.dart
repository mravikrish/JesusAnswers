import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/natural_voices.dart';
import '../../services/voice/tts_service.dart';
import '../device_settings.dart';
import '../languages.dart';
import '../theme/app_theme.dart';

/// Reads [parts] aloud — His words ([VoiceRole.jesus]) in the male voice,
/// everything else in the female one — or, if there is neither a natural voice
/// nor a phone voice for [lang], explains and offers the phone's voice download.
Future<void> readAloud(BuildContext context, List<String> parts, AppLanguage lang,
    {VoiceRole role = VoiceRole.verse}) async {
  final tts = ProviderScope.containerOf(context, listen: false).read(ttsProvider);
  final natural = naturalVoiceFor(lang.code, role);
  if ((natural != null && await tts.voices.isInstalled(natural)) || await tts.hasVoice(lang)) {
    await tts.speak(parts, lang, role: role);
    return;
  }
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final download = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.record_voice_over_outlined, color: AppColors.gold),
      content: Text(l.noVoice(lang.nativeName), textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.download_rounded),
          label: Text(l.downloadVoice),
        ),
      ],
    ),
  );
  if (download ?? false) await DeviceSettings.ttsVoices();
}

/// Play → Pause / Resume, Stop, a "Slower" toggle that is remembered,
/// and — with [onExpand] — a button to open the full-screen player.
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key, required this.label, required this.onPlay, this.dark = false, this.onExpand});

  /// "Play Answer", "Listen"… shown before anything is playing.
  final String label;
  final VoidCallback onPlay;
  final VoidCallback? onExpand;

  /// White outlined style for night screens; filled gold on light screens.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tts = ref.watch(ttsProvider);
    final fg = dark ? Colors.white : AppColors.ink;

    Widget main(IconData icon, String text, VoidCallback onPressed) => dark
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: const StadiumBorder(),
            ),
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(text),
          )
        : FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(text));

    return ValueListenableBuilder(
      valueListenable: tts.playback,
      builder: (_, playback, _) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          switch (playback) {
            Playback.idle => main(Icons.play_arrow_rounded, label, onPlay),
            Playback.playing => main(Icons.pause_rounded, l.pause, tts.pause),
            Playback.paused => main(Icons.play_arrow_rounded, l.resume, tts.resume),
          },
          if (playback != Playback.idle)
            IconButton(
              tooltip: l.stop,
              onPressed: tts.stop,
              icon: Icon(Icons.stop_rounded, color: fg),
            ),
          SlowerToggle(dark: dark),
          MusicToggle(dark: dark),
          if (onExpand != null)
            IconButton(
              tooltip: l.fullScreen,
              onPressed: onExpand,
              icon: Icon(Icons.open_in_full_rounded, color: fg),
            ),
        ],
      ),
    );
  }
}

/// "Slower" on / off, remembered for next time.
class SlowerToggle extends ConsumerWidget {
  const SlowerToggle({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsProvider);
    final fg = dark ? Colors.white : AppColors.ink;
    return ValueListenableBuilder(
      valueListenable: tts.slow,
      // A plain button with every colour set by hand: FilterChip took its fill
      // and label colours from the theme, leaving white text on a cream chip.
      builder: (_, slow, _) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: slow ? AppColors.goldSoft : Colors.transparent,
          foregroundColor: slow ? AppColors.ink : fg,
          iconColor: slow ? AppColors.ink : fg,
          side: BorderSide(color: slow ? AppColors.goldSoft : (dark ? Colors.white54 : AppColors.sand)),
          shape: const StadiumBorder(),
        ),
        onPressed: () => tts.setSlow(!slow),
        icon: const Icon(Icons.slow_motion_video_rounded, size: 18),
        label: Text(AppLocalizations.of(context).speakSlower),
      ),
    );
  }
}

/// Shown above the bottom menu while something is being read aloud, so it can
/// be paused or stopped from anywhere — e.g. after leaving Today's Word playing.
class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key, required this.dark});

  /// Light text for the night-sky tabs, dark text for the ivory ones.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tts = ref.watch(ttsProvider);
    final fg = dark ? Colors.white : AppColors.ink;
    return ValueListenableBuilder(
      valueListenable: tts.playback,
      builder: (_, playback, _) {
        if (playback == Playback.idle) return const SizedBox.shrink();
        final playing = playback == Playback.playing;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: AppColors.gold.withValues(alpha: dark ? 0.22 : 0.16),
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(playing ? Icons.graphic_eq_rounded : Icons.pause_circle_outline_rounded,
                      color: AppColors.gold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: tts.progress,
                      builder: (_, progress, _) => LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: AppColors.gold,
                        backgroundColor: fg.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: playing ? l.pause : l.resume,
                    onPressed: playing ? tts.pause : tts.resume,
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: fg),
                  ),
                  IconButton(
                    tooltip: l.stop,
                    onPressed: tts.stop,
                    icon: Icon(Icons.stop_rounded, color: fg),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soft music under the voice, on or off, remembered for next time.
class MusicToggle extends ConsumerWidget {
  const MusicToggle({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsProvider);
    final fg = dark ? Colors.white : AppColors.ink;
    return ValueListenableBuilder(
      valueListenable: tts.music,
      builder: (_, on, _) => FilterChip(
        label: Text(AppLocalizations.of(context).music),
        avatar: Icon(on ? Icons.music_note_rounded : Icons.music_off_rounded,
            size: 18, color: on ? AppColors.gold : fg.withValues(alpha: 0.7)),
        selected: on,
        showCheckmark: false,
        onSelected: tts.setMusic,
        labelStyle: TextStyle(color: fg),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.gold.withValues(alpha: 0.18),
        side: BorderSide(color: fg.withValues(alpha: 0.3)),
        shape: const StadiumBorder(),
      ),
    );
  }
}
