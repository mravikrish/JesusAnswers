import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Write to us — type or speak, then Send. Delivered to the feedback form; no email exposed.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Uses the same listening screen as talking to Jesus, so mic problems are explained there too.
  Future<void> _speak() async {
    final words = await context.push<String>('/listen');
    if (words == null || words.trim().isEmpty || !mounted) return;
    final current = _text.text.trimRight();
    setState(() => _text.text = current.isEmpty ? words.trim() : '$current ${words.trim()}');
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final ok = await ref.read(feedbackServiceProvider).send(_text.text, ref.read(settingsProvider).language);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).feedbackFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: NightPanel.appBar(
        title: Text(l.sendFeedback, style: AppText.serif(24, weight: FontWeight.w600, color: Colors.white)),
      ),
      body: SafeArea(
        child: _sent ? _thanks(l) : _form(l),
      ),
    );
  }

  Widget _form(AppLocalizations l) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(l.feedbackIntro, style: const TextStyle(fontSize: 16, height: 1.45, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            minLines: 6,
            maxLines: 12,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.feedbackHint,
              filled: true,
              fillColor: AppColors.ivoryCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.sand),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.sand),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _sending ? null : _speak,
                icon: const Icon(Icons.mic_rounded, color: AppColors.gold),
                label: Text(l.speakFreely),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.sand),
                  shape: const StadiumBorder(),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(l.send),
              ),
            ],
          ),
        ],
      );

  Widget _thanks(AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 72),
              const SizedBox(height: 20),
              Text(l.feedbackThanks, textAlign: TextAlign.center, style: AppText.serif(24, weight: FontWeight.w600)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.pop(), child: Text(MaterialLocalizations.of(context).okButtonLabel)),
            ],
          ),
        ),
      );
}
