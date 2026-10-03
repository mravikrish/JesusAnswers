import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/divine_light.dart';
import '../../core/widgets/glow_mic_button.dart';
import '../../core/widgets/night_background.dart';
import '../../data/models/painting.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Home — opens on today's painting of Jesus, as if coming into His presence,
/// with one clear invitation: talk to Him.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    ask(context, _text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = ref.watch(settingsProvider.select((s) => s.name));
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? l.greetingMorning : (hour < 17 ? l.greetingAfternoon : l.greetingEvening);
    final verse = ref.watch(dailyVerseProvider).value;
    final painting = ref.watch(dailyPaintingProvider).value;
    final heroHeight = MediaQuery.sizeOf(context).height * 0.5;

    return Scaffold(
      body: NightBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Hero(
              painting: painting,
              height: heroHeight,
              greeting: greeting,
              name: name.isEmpty ? l.friend : name,
              invite: l.homeInvite,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  if (verse != null)
                    GestureDetector(
                      onTap: () => context.go('/word'),
                      child: GlassCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome, size: 16, color: AppColors.goldSoft),
                                const SizedBox(width: 6),
                                Text(l.todaysWord,
                                    style: const TextStyle(
                                        color: AppColors.goldSoft, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            VerseQuote(verse: verse, dark: true, size: 20, center: true),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  GlowMicButton(size: 104, onTap: () => talk(context)),
                  Text(l.tapToTalk, textAlign: TextAlign.center, style: AppText.serif(30, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(l.tapToTalkHint,
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _text,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l.typeHint,
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded, color: AppColors.goldSoft),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Daily Word, Pray and Profile are in the bottom bar; Peace Now, Bible Stories and Pictures are the extra ways in.
                  _QuickAction(icon: Icons.spa_rounded, label: l.peaceNow, onTap: () => context.push('/peace')),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.auto_stories_rounded,
                    label: l.bibleStories,
                    onTap: () => context.push('/stories'),
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.photo_library_rounded,
                    label: l.picturesTitle,
                    onTap: () => context.push('/pictures'),
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

/// Today's painting, fading into the night sky, with the greeting over it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.painting,
    required this.height,
    required this.greeting,
    required this.name,
    required this.invite,
  });

  final Painting? painting;
  final double height;
  final String greeting;
  final String name;
  final String invite;

  static Future<void> _openInGallery(BuildContext context, Painting painting) async {
    final all = await Painting.all();
    if (!context.mounted) return;
    context.push('/pictures/${all.indexWhere((p) => p.asset == painting.asset)}');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height + 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            // Tap today's picture to open it in the Pictures gallery, ready to save or share.
            child: GestureDetector(
              onTap: painting == null ? null : () => _openInGallery(context, painting!),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                child: painting == null
                    ? const SizedBox.expand()
                    : Image.asset(
                        painting!.asset,
                        key: ValueKey(painting!.asset),
                        fit: BoxFit.cover,
                        alignment: painting!.focus,
                        errorBuilder: (_, _, _) => Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                      ),
              ),
            ),
          ),
          // Fade the painting into the sky: dark at the top for the status bar,
          // fully midnight at the bottom so the greeting reads clearly.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height + 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99060C1E), Color(0x00060C1E), Color(0x330A1430), Color(0xE60A1430), AppColors.midnight],
                  stops: [0, 0.22, 0.5, 0.82, 1],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: DivineLight(intensity: 0.7))),
          if (painting?.credit case final credit?)
            Positioned(
              top: top + 18,
              left: 18,
              right: 18,
              child: Text(
                credit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
            ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: AppText.serif(24, color: AppColors.goldSoft)),
                Text(name, style: AppText.serif(38, color: Colors.white, weight: FontWeight.w600, height: 1.05)),
                const SizedBox(height: 6),
                Text(invite, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppColors.goldSoft.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.gold.withValues(alpha: 0.45),
                      AppColors.gold.withValues(alpha: 0.08),
                    ]),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16))),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      );
}
