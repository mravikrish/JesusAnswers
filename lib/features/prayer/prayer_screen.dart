import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/divine_light.dart';
import '../../data/models/answer.dart';
import '../../l10n/app_localizations.dart';

/// "Pray With Me" — the user shares a request and receives a Scripture-based prayer.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6E3C2), AppColors.ivory],
            stops: [0, 0.45],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: DivineLight(color: AppColors.gold, intensity: 0.5)),
            ),
            SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 40)],
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded, size: 48, color: AppColors.ember),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l.prayTitle,
                    textAlign: TextAlign.center,
                    style: AppText.serif(34, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.prayPrompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 26),
                  OutlinedButton.icon(
                    onPressed: _speak,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.gold),
                      foregroundColor: AppColors.ink,
                    ),
                    icon: const Icon(Icons.mic_rounded, color: AppColors.gold),
                    label: Text(l.speakFreely),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(hintText: l.prayHint),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: _generate, child: Text(l.generatePrayer)),
                  const SizedBox(height: 28),
                  // Or choose a ready prayer and hear it.
                  Material(
                    color: Colors.white.withValues(alpha: 0.75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.goldSoft),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: const Icon(Icons.menu_book_rounded, color: AppColors.ember, size: 30),
                      title: Text(l.readyPrayers, style: AppText.serif(20, weight: FontWeight.w700)),
                      subtitle: Text(l.readyPrayersHint),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
                      onTap: () => context.push('/prayers'),
                    ),
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
