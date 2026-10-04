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
