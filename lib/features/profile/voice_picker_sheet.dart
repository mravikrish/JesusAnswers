import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/tts_service.dart';

/// Lists the device's voices for the current language. Tap ▶ to hear today's verse, tap a row to choose it.
class VoicePickerSheet extends ConsumerStatefulWidget {
  const VoicePickerSheet({super.key});

  @override
  ConsumerState<VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends ConsumerState<VoicePickerSheet> {
  late final _tts = ref.read(ttsProvider);

  @override
  void initState() {
    super.initState();
    // Take the voice now: ref can't be used once the screen is closing, and without
    // this the voice kept playing after leaving. Warming it up also starts Listen sooner.
    _tts.warmUp(ref.read(settingsProvider).language);
  }
  late final _voices = _tts.voicesFor(ref.read(settingsProvider).language);

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _preview(TtsVoice? voice) {
    final settings = ref.read(settingsProvider);
    final text = ref.read(dailyVerseProvider).value?.text ?? settings.language.nativeName;
    _tts.speak([text], settings.language, voice: voice);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(settingsProvider.select((s) => s.voice));
    final check = const Icon(Icons.check_rounded, color: AppColors.gold);

    return SafeArea(
      child: FutureBuilder(
        future: _voices,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          final voices = snap.data!;
          return ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(l.voiceMale),
                subtitle: Text('Automatic · ${voices.length} voices on this device'),
                leading: selected.isEmpty ? check : const SizedBox(width: 24),
                trailing: IconButton(icon: const Icon(Icons.play_arrow_rounded), onPressed: () => _preview(null)),
                onTap: () => ref.read(settingsProvider.notifier).setVoice(null),
              ),
              for (final v in voices)
                ListTile(
                  title: Text(v.name),
                  subtitle: Text([v.locale, if (v.male) 'male', if (v.needsNetwork) 'needs internet'].join(' · ')),
                  leading: v.name == selected ? check : const SizedBox(width: 24),
                  trailing: IconButton(icon: const Icon(Icons.play_arrow_rounded), onPressed: () => _preview(v)),
                  onTap: () {
                    ref.read(settingsProvider.notifier).setVoice(v.name);
                    _preview(v);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
