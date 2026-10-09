import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/picture_share.dart';
import '../../core/share.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/circle_service.dart';

/// The message that goes with an invite: the code, the link that opens the app to join, and where to get it.
String inviteMessage(AppLocalizations l, String name, String code) => [
      l.circleInviteText(name, CircleService.showCode(code)),
      // Opens the app to join, or shows where to get it.
      if (apiBaseUrl.isNotEmpty) CircleService.joinLink(code, baseUrl: apiBaseUrl),
      '',
      shareFooter(l),
    ].join('\n');

/// A circle's invite, large enough for the church's projector or TV: a QR code that phone cameras open
/// straight into the app's Join, and the code itself for anyone typing it in. The screen stays on.
/// Share sends the same card as a picture, for WhatsApp groups and church notices.
class CircleShowScreen extends StatefulWidget {
  const CircleShowScreen({super.key, required this.code, required this.name});
  final String code, name;

  @override
  State<CircleShowScreen> createState() => _CircleShowScreenState();
}

class _CircleShowScreenState extends State<CircleShowScreen> {
  final _card = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Not on every platform (or in tests); the page works without it.
    WakelockPlus.enable().catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _share() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      await PictureShare.share(await PictureShare.render(boundary), inviteMessage(l, widget.name, widget.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              final qrSize = (wide ? box.maxHeight * 0.7 : box.maxWidth * 0.7).clamp(160.0, 520.0);
              final qr = Container(
                padding: EdgeInsets.all(qrSize * 0.06),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: QrImageView(
                  data: CircleService.joinLink(widget.code, baseUrl: apiBaseUrl),
                  size: qrSize,
                  padding: EdgeInsets.zero,
                  semanticsLabel: CircleService.showCode(widget.code),
                ),
              );
              final words = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text(widget.name,
                      textAlign: wide ? TextAlign.start : TextAlign.center,
                      style: AppText.serif(wide ? 40 : 30, weight: FontWeight.w700, color: AppColors.goldSoft)),
                  const SizedBox(height: 6),
                  Text(l.circleScreenTitle,
                      textAlign: wide ? TextAlign.start : TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: wide ? 26 : 20)),
                  const SizedBox(height: 18),
                  FittedBox(
                    child: Text(CircleService.showCode(widget.code),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 72, fontWeight: FontWeight.w800, letterSpacing: 8)),
                  ),
                  const SizedBox(height: 18),
                  Text(l.circleScreenSteps,
                      textAlign: wide ? TextAlign.start : TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: wide ? 20 : 16, height: 1.4)),
                ],
              );
              // The part that is shared as a picture, with its own background so it stands alone.
              final card = RepaintBoundary(
                key: _card,
                child: ColoredBox(
                  color: AppColors.midnight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: wide
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            qr,
                            const SizedBox(width: 48),
                            Flexible(child: words),
                          ])
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            words,
                            const SizedBox(height: 28),
                            qr,
                          ]),
                  ),
                ),
              );
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Center(child: wide ? card : SingleChildScrollView(child: card)),
              );
            }),
            PositionedDirectional(
              top: 4,
              start: 4,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6)),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton(
                tooltip: l.circleInvite,
                icon: Icon(Icons.ios_share_rounded, color: Colors.white.withValues(alpha: _busy ? 0.3 : 0.8)),
                onPressed: _busy ? null : _share,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
