import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/languages.dart';

/// Why the mic didn't work, so the listening screen can say what to do.
enum MicProblem {
  /// Microphone permission was refused → "Allow microphone in Settings".
  permission,

  /// The recognizer can't do this language (common for Telugu, Odia… without Google's voice data).
  language,

  /// It listened but heard nothing it could understand → try again.
  noSpeech,

  /// No speech recognizer on this phone at all → type instead.
  unavailable,
}

class MicException implements Exception {
  const MicException(this.problem);
  final MicProblem problem;
}

/// Speech-to-text in the user's chosen language.
class SpeechService {
  final _stt = SpeechToText();
  bool _ready = false;

  /// Not cached when it fails: the user may allow the mic in Settings and come back.
  Future<bool> init() async => _ready = _ready || await _stt.initialize(onError: (_) {}, onStatus: (_) {});

  bool get isListening => _stt.isListening;

  /// Throws [MicException] if listening can't start. Problems found while listening
  /// (language not supported, nothing heard…) arrive through [onProblem].
  Future<void> listen({
    required AppLanguage lang,
    required void Function(String words, bool isFinal) onResult,
    required void Function(MicProblem problem) onProblem,
    void Function(double level)? onLevel,
  }) async {
    if (!await init()) {
      final allowed = await _stt.hasPermission.catchError((_) => false);
      throw MicException(allowed ? MicProblem.unavailable : MicProblem.permission);
    }
    _stt.errorListener = (e) {
      final problem = _problemFor(e.errorMsg);
      if (problem != null) onProblem(problem);
    };
    final locales = await _stt.locales();
    final match = locales.where((l) => l.localeId.replaceAll('-', '_') == lang.sttId).firstOrNull ??
        locales.where((l) => l.localeId.startsWith(lang.code)).firstOrNull;

    await _stt.listen(
      listenOptions: SpeechListenOptions(
        // Many Android phones list only the system locale here even though Google's
        // recognizer supports every Indian language. Never pass null — that silently
        // falls back to the system language (usually English) and the user's Telugu
        // comes back as romanised English words. Ask for the language explicitly.
        localeId: match?.localeId ?? lang.ttsTag, // BCP-47, e.g. "te-IN"
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: true,
      ),
      onSoundLevelChange: onLevel,
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
    );
  }

  /// Android recognizer error codes (speech_to_text passes them through).
  static MicProblem? _problemFor(String error) => switch (error) {
        'error_permission' || 'error_insufficient_permissions' => MicProblem.permission,
        'error_language_not_supported' || 'error_language_unavailable' => MicProblem.language,
        'error_no_match' || 'error_speech_timeout' => MicProblem.noSpeech,
        'error_client' || 'error_recognizer_busy' || 'error_busy' => null, // transient; the user can tap again
        _ => MicProblem.unavailable,
      };

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
