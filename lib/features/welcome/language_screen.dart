import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/languages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// First launch: splash + language choice. Each language is shown in its own
/// script so people can find theirs without reading English.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(settingsProvider).lang;

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const LogoMark(size: 64),
                const SizedBox(height: 16),
                const Wordmark(size: 40),
                Text(l.tagline, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 28),
                Text(l.chooseLanguage, style: AppText.serif(22, color: Colors.white)),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: [
                      for (final lang in appLanguages)
                        _LanguageTile(
                          lang: lang,
                          selected: lang.code == current,
                          onTap: () => ref.read(settingsProvider.notifier).setLanguage(lang.code),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: () async {
                      await ref.read(settingsProvider.notifier).setLanguage(current);
                      if (context.mounted) context.go('/home');
                    },
                    child: Text(l.continueLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.lang, required this.selected, required this.onTap});
  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.gold.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? AppColors.gold : Colors.white.withValues(alpha: 0.14)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lang.nativeName,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                if (lang.nativeName != lang.englishName)
                  Text(lang.englishName,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}
