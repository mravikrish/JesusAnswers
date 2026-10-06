import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/answer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../bible/bible_screen.dart';

/// "Pray With Me" — the user shares a request and receives a Scripture-based prayer.
/// Under today's painting of Jesus in the night sky, as on Home.
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final words = await context.push<String>('/listen');
    if (words != null && words.trim().isNotEmpty && mounted) {
      ask(context, words, kind: AnswerKind.prayer, spoken: true);
    }
  }

  void _generate() {
    if (_text.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    ask(context, _text.text, kind: AnswerKind.prayer);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final painting = ref.watch(screenPaintingProvider(PaintingSpot.pray)).value;
    final soft = Colors.white.withValues(alpha: 0.75);
    return Scaffold(
      body: NightBackground(
        warm: true,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            PaintingHero(
              painting: painting,
              height: MediaQuery.sizeOf(context).height * 0.42,
              child: Column(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, size: 40, color: AppColors.goldSoft),
                  const SizedBox(height: 8),
                  Text(l.prayTitle,
                      textAlign: TextAlign.center,
                      style: AppText.serif(34, color: Colors.white, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(l.prayPrompt, textAlign: TextAlign.center, style: TextStyle(color: soft)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _speak,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.gold),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.mic_rounded, color: AppColors.goldSoft),
                    label: Text(l.speakFreely),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: l.prayHint,
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.midnight),
                    onPressed: _generate,
                    child: Text(l.generatePrayer),
                  ),
                  const SizedBox(height: 28),
                  // Or choose a ready prayer and hear it.
                  _Choice(
                    icon: Icons.menu_book_rounded,
                    title: l.readyPrayers,
                    hint: l.readyPrayersHint,
                    onTap: () => context.push('/prayers'),
                  ),
                  const SizedBox(height: 12),
                  // Or pray for each other with family and friends.
                  _Choice(
                    icon: Icons.groups_rounded,
                    title: l.circlesTitle,
                    hint: l.circlesHint,
                    onTap: () => context.push('/circles'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A way on from praying here: Ready Prayers, Prayer Circles.
class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.hint, required this.onTap});
  final IconData icon;
  final String title, hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.07),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon, color: AppColors.goldSoft, size: 30),
      title: Text(title, style: AppText.serif(20, color: Colors.white, weight: FontWeight.w700)),
      subtitle: Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.goldSoft),
      onTap: onTap,
    ),
  );
}
