import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/device_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glow_mic_button.dart';
import '../../core/widgets/night_background.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/voice/speech_service.dart';

/// Full-screen listening orb. Pops with the transcript (or null if cancelled).
class ListeningScreen extends ConsumerStatefulWidget {
  const ListeningScreen({super.key});

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen> with WidgetsBindingObserver {
  String _words = '';
  double _level = 0;
  MicProblem? _problem;
  bool _done = false;
  late final _tts = ref.read(ttsProvider);
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts
      ..stop()
      ..setAmbient(false); // no music while the microphone listens
    _start();
  }

  /// Back from Settings (mic allowed, or a voice-input language added) — try again by itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_problem == MicProblem.permission || _problem == MicProblem.language)) {
      _start();
    }
  }

  Future<void> _start() async {
    if (_problem != null) {
      setState(() {
        _problem = null;
        _words = '';
      });
    }
    try {
      await ref.read(speechProvider).listen(
            lang: ref.read(settingsProvider).language,
            onLevel: (db) {
              // Platform levels are roughly -2..10 dB; normalise to 0..1.
              if (mounted) setState(() => _level = ((db + 2) / 12).clamp(0, 1));
            },
            onResult: (words, isFinal) {
              if (!mounted) return;
              setState(() => _words = words);
              if (isFinal) _finish();
            },
            onProblem: _showProblem,
          );
    } on MicException catch (e) {
      _showProblem(e.problem);
    } catch (_) {
      _showProblem(MicProblem.unavailable);
    }
  }

  void _showProblem(MicProblem problem) {
    if (!mounted || _done) return;
    // Something was heard before the error: answer that rather than complain.
    if (problem == MicProblem.noSpeech && _words.trim().isNotEmpty) return _finish();
    setState(() {
      _problem = problem;
      _level = 0;
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    ref.read(speechProvider).stop();
    context.pop(_typed.text.trim().isNotEmpty ? _typed.text : _words);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_done) ref.read(speechProvider).cancel();
    _tts.setAmbient(true);
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final painting = ref.watch(dailyPaintingProvider).value;
    final problem = _problem;
    final language = ref.watch(settingsProvider.select((s) => s.language));
    final (message, actionLabel, action) = switch (problem) {
      null => (l.listeningHint, null, null),
      MicProblem.permission => (l.micPermission, l.openSettings, DeviceSettings.app),
      MicProblem.language => (l.micLanguage(language.nativeName), l.voiceSettings, DeviceSettings.voiceInput),
      MicProblem.noSpeech => (l.micNoSpeech, l.tryAgain, _start),
      MicProblem.unavailable => (l.micUnavailable, null, null),
    };

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          // Scrolls only when the keyboard is up for typing instead.
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () {
                            _done = true;
                            ref.read(speechProvider).cancel();
                            context.pop();
                          },
                        ),
                      ),
                      const Spacer(),
                      GlowMicButton(
                        size: problem == null ? 150 : 110,
                        level: _level,
                        color: AppColors.gold,
                        image: painting == null ? null : AssetImage(painting.asset),
                        imageFocus: painting?.focus ?? Alignment.center,
                        // While listening, tap to finish; after "nothing heard", tap to listen again.
                        onTap: switch (problem) {
                          null => _finish,
                          MicProblem.noSpeech => _start,
                          _ => null,
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(l.listening, textAlign: TextAlign.center, style: AppText.serif(34, color: Colors.white)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.4),
                        ),
                      ),
                      if (action != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                            onPressed: action,
                            icon: Icon(problem == MicProblem.noSpeech ? Icons.mic_rounded : Icons.settings_rounded),
                            label: Text(actionLabel!),
                          ),
                        ),
                      // What they're saying, appearing as they speak — like a message being written.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _words.isEmpty
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                width: double.infinity,
                                margin: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.goldSoft.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _words,
                                  textAlign: TextAlign.center,
                                  style: AppText.serif(21, color: Colors.white, height: 1.35),
                                ),
                              ),
                      ),
                      // Typing always works, whatever went wrong with the mic.
                      if (problem != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: TextField(
                            controller: _typed,
                            autofocus: problem == MicProblem.unavailable,
                            maxLines: 3,
                            minLines: 1,
                            onSubmitted: (_) => _finish(),
                            decoration: InputDecoration(
                              hintText: l.typeInstead,
                              suffixIcon: IconButton(icon: const Icon(Icons.send_rounded), onPressed: _finish),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (problem == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Material(
                            color: AppColors.heart,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _finish,
                              child: const SizedBox.square(
                                dimension: 64,
                                child: Icon(Icons.stop_rounded, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
