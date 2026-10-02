import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/tts_service.dart';
import '../device_settings.dart';
import '../languages.dart';
import '../theme/app_theme.dart';

/// Reads [parts] aloud, or — if the phone has no voice for [lang] — explains
/// and offers to open the phone's voice download screen.
Future<void> readAloud(BuildContext context, List<String> parts, AppLanguage lang) async {
  final tts = ProviderScope.containerOf(context, listen: false).read(ttsProvider);
  if (await tts.hasVoice(lang)) {
    await tts.speak(parts, lang);
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

/// Play → Pause / Resume, Stop, and a "Slower" toggle that is remembered.
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key, required this.label, required this.onPlay, this.dark = false});

  /// "Play Answer", "Listen"… shown before anything is playing.
  final String label;
  final VoidCallback onPlay;

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
          ValueListenableBuilder(
            valueListenable: tts.slow,
            builder: (_, slow, _) => FilterChip(
              label: Text(l.speakSlower),
              avatar: Icon(Icons.slow_motion_video_rounded, size: 18, color: slow ? AppColors.ink : fg),
              selected: slow,
              showCheckmark: false,
              selectedColor: AppColors.goldSoft,
              backgroundColor: Colors.transparent,
              labelStyle: TextStyle(color: slow ? AppColors.ink : fg),
              shape: StadiumBorder(side: BorderSide(color: dark ? Colors.white38 : AppColors.sand)),
              onSelected: tts.setSlow,
            ),
          ),
        ],
      ),
    );
  }
}
