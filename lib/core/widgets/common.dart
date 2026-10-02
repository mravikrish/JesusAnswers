import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/verse.dart';
import '../../l10n/app_localizations.dart';
import '../share.dart';
import '../theme/app_theme.dart';

/// "JesusAnswers" wordmark — "Answers" slightly lighter than "Jesus".
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 40, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Jesus', style: AppText.serif(size, color: color, weight: FontWeight.w700)),
          TextSpan(text: 'Answers', style: AppText.serif(size, color: color.withValues(alpha: 0.85), weight: FontWeight.w400)),
        ]),
      );
}

/// App logo: the cross of light over the mountains (same image as the launcher icon).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: size * 0.3)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
        ),
      );
}

/// Light card used on ivory screens.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppColors.ivoryCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sand),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

/// Translucent card for dark screens.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: child,
      );
}

/// Scripture quote + reference, styled for light or dark backgrounds.
/// With [shareable], a long-press or the small share icon copies or shares just this verse.
class VerseQuote extends StatelessWidget {
  const VerseQuote({
    super.key,
    required this.verse,
    this.dark = false,
    this.size = 21,
    this.center = false,
    this.shareable = false,
  });
  final Verse verse;
  final bool dark;
  final double size;
  final bool center;
  final bool shareable;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : AppColors.ink;
    final accent = dark ? AppColors.goldSoft : AppColors.ember;
    final align = center ? TextAlign.center : TextAlign.start;
    final reference = Text(
      '${verse.reference} · ${verse.translation}',
      textAlign: align,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
    );
    final quote = Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text('“${verse.text}”', textAlign: align, style: AppText.serif(size, color: color, height: 1.35)),
        SizedBox(height: shareable ? 2 : 10),
        if (!shareable)
          reference
        else
          Row(
            mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Flexible(child: reference),
              IconButton(
                tooltip: AppLocalizations.of(context).shareVerse,
                visualDensity: VisualDensity.compact,
                onPressed: () => showVerseActions(context, verse),
                icon: Icon(Icons.ios_share_rounded, size: 18, color: accent),
              ),
            ],
          ),
      ],
    );
    return shareable ? GestureDetector(onLongPress: () => showVerseActions(context, verse), child: quote) : quote;
  }
}

/// Shown before anything else when a message suggests the person may be at risk.
class CrisisCard extends StatelessWidget {
  const CrisisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget line(IconData icon, String text, String? uri) => InkWell(
          onTap: uri == null ? null : () => launchUrl(Uri.parse(uri)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(icon, size: 20, color: AppColors.heart),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: uri == null ? null : TextDecoration.underline,
                    )),
              ),
            ]),
          ),
        );

    return SoftCard(
      color: const Color(0xFFFFF1F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.crisisTitle, style: AppText.serif(22, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(l.crisisBody, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          line(Icons.phone_rounded, l.crisisIndia, 'tel:14416'),
          line(Icons.phone_rounded, l.crisisUS, 'tel:988'),
          line(Icons.public_rounded, l.crisisFind, 'https://findahelpline.com'),
          const SizedBox(height: 4),
          Text(l.crisisEmergency, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
