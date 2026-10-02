import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../core/widgets/playback_controls.dart';
import '../../data/bible/bible_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Today's Word — like opening a daily letter from Scripture.
class DailyWordScreen extends ConsumerStatefulWidget {
  const DailyWordScreen({super.key});

  @override
  ConsumerState<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends ConsumerState<DailyWordScreen> {
  late final _tts = ref.read(ttsProvider);

  @override
  void deactivate() {
    _tts.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final verse = ref.watch(dailyVerseProvider).value;
    final date = DateFormat.yMMMMd(settings.lang).format(DateTime.now());

    return Scaffold(
      body: NightBackground(
        warm: true,
        child: SafeArea(
          bottom: false,
          child: verse == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.goldSoft))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
                  children: [
                    Text(l.todaysWord, textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white)),
                    Text(date,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.gold.withValues(alpha: 0.18),
                          border: Border.all(color: AppColors.goldSoft.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.goldSoft, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              l.dayOfYear(BibleRepository.dayIndex(DateTime.now()) + 1, 365),
                              style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    VerseQuote(verse: verse, dark: true, size: 28, center: true, shareable: true),
                    const SizedBox(height: 22),
                    PlaybackControls(
                      dark: true,
                      label: l.listen,
                      onPlay: () =>
                          readAloud(context, [verse.reference, verse.text, l.dailyEncouragement], settings.language),
                    ),
                    const SizedBox(height: 26),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.favorite_rounded, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(l.todaysMessage, style: AppText.serif(20, weight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 10),
                          Text(l.dailyEncouragement, style: const TextStyle(height: 1.5, fontSize: 15)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => shareVerse(verse, l),
                              icon: const Icon(Icons.ios_share_rounded, color: AppColors.ink),
                              label: Text(l.share, style: const TextStyle(color: AppColors.ink)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
