import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/divine_light.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/mood.dart';
import '../../l10n/app_localizations.dart';

/// "What are you feeling today?" — a gentle way in without forming a question.
class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: NightPanel.appBar(title: const SizedBox()),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: DivineLight(color: AppColors.gold, intensity: 0.35)),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                l.moodTitle,
                textAlign: TextAlign.center,
                style: AppText.serif(32, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                l.moodSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final m in Mood.values)
                    _MoodTile(
                      emoji: m.emoji,
                      label: m.label(l),
                      tint: m.tint,
                      onTap: () => ask(context, m.label(l), mood: m.name),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Material(
                color: AppColors.ivoryCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.sand),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  leading: const Icon(Icons.mic_none_rounded, color: AppColors.navy),
                  title: Text(l.moodOther),
                  onTap: () => talk(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({required this.emoji, required this.label, required this.tint, required this.onTap});
  final String emoji;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.ivoryCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.sand),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}
