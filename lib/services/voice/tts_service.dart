import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/languages.dart';

/// A voice offered by the device's TTS engine.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.male = false, this.needsNetwork = false});

  final String name;
  final String locale;

  /// Best guess — engines rarely report gender, so this also matches known male voice names.
  final bool male;
  final bool needsNetwork;

  Map<String, String> toMap() => {'name': name, 'locale': locale};
}

enum Playback { idle, playing, paused }

/// The calm voice of JesusAnswers: slower, slightly lower, with pauses
/// between the parts of an answer. Can pause and resume mid-sentence.
///
/// Uses the device's TTS engine (works offline in all supported languages
/// when the voice data is installed). For production, swap in a neural cloud
/// voice with the same interface for a warmer, more consistent male voice.
class TtsService {
  TtsService(this._prefs) {
    slow.value = _prefs.getBool(_slowKey) ?? false;
    // Remember where we are in the current part, so Pause → Resume carries on from that word.
    _tts.setProgressHandler((_, start, _, _) => _offset = _partStart + start);
  }

  final SharedPreferences _prefs;
  final _tts = FlutterTts();

  final playback = ValueNotifier(Playback.idle);

  /// Read more slowly than the normal calm pace. Saved for next time.
  final slow = ValueNotifier(false);

  static const _slowKey = 'ttsSlow';
  static const _normalRate = 0.42, _slowRate = 0.32;

  int _session = 0;
  String? _configuredFor;

  // What is being read, and how far it has got.
  List<String> _parts = const [];
  AppLanguage? _lang;
  TtsVoice? _voice;
  int _index = 0;
  int _offset = 0;
  int _partStart = 0;

  /// Where the voice chosen in Profile is saved, per language. Absent = pick a male voice automatically.
  static String voiceKey(String lang) => 'voice.$lang';

  /// Voices for [lang] on this device, likely-male first.
  Future<List<TtsVoice>> voicesFor(AppLanguage lang) async {
    try {
      final voices = [
        for (final v in (await _tts.getVoices as List).cast<Map>())
          if (_matches('${v['locale']}', lang)) _toVoice(v),
      ];
      voices.sort((a, b) => a.male != b.male ? (a.male ? -1 : 1) : a.name.compareTo(b.name));
      return voices;
    } catch (_) {
      return const []; // Voice listing isn't supported everywhere.
    }
  }

  /// False when the phone can't read [lang] aloud — its voice data isn't installed.
  Future<bool> hasVoice(AppLanguage lang) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _tts.isLanguageAvailable(lang.ttsTag) == true;
      }
      return (await voicesFor(lang)).isNotEmpty;
    } catch (_) {
      return true; // Can't tell — don't nag.
    }
  }

  static bool _matches(String locale, AppLanguage lang) {
    final l = locale.toLowerCase().replaceAll('_', '-');
    return l == lang.code || l.startsWith('${lang.code}-');
  }

  static TtsVoice _toVoice(Map v) {
    final name = '${v['name']}';
    final s = '$name ${v['gender'] ?? ''}'.toLowerCase();
    return TtsVoice(
      name: name,
      locale: '${v['locale']}',
      male: (s.contains('male') && !s.contains('female')) ||
          // Known male voices: Google Android Indian voices / iOS
          RegExp(r'-x-(iom|iol|tpd|ahp|cxx|hie)|rishi|daniel|aaron|arthur').hasMatch(s),
      needsNetwork: '${v['network_required']}' == '1' || s.contains('network'),
    );
  }

  Future<void> _configure(AppLanguage lang, TtsVoice? override) async {
    final wanted = override?.name ?? _prefs.getString(voiceKey(lang.code));
    final key = '${lang.code}|$wanted|${slow.value}';
    if (_configuredFor == key) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(lang.ttsTag);
    await _tts.setSpeechRate(slow.value ? _slowRate : _normalRate);
    await _tts.setPitch(0.88);

    final voices = await voicesFor(lang);
    final pick = voices.where((v) => v.name == wanted).firstOrNull ?? voices.where((v) => v.male).firstOrNull;
    if (pick != null) await _tts.setVoice(pick.toMap());
    _configuredFor = key;
  }

  /// Speaks [parts] in order with a gentle pause between each.
  /// [voice] overrides the saved choice (used to preview voices).
  Future<void> speak(List<String> parts, AppLanguage lang, {TtsVoice? voice}) async {
    await stop();
    _parts = [for (final p in parts) if (p.trim().isNotEmpty) p];
    _lang = lang;
    _voice = voice;
    _index = 0;
    _offset = 0;
    await _run();
  }

  /// Stops mid-sentence; [resume] carries on from the same word.
  Future<void> pause() async {
    if (playback.value != Playback.playing) return;
    _session++;
    playback.value = Playback.paused;
    await _tts.stop();
  }

  Future<void> resume() async {
    if (playback.value == Playback.paused) await _run();
  }

  Future<void> setSlow(bool value) async {
    slow.value = value;
    await _prefs.setBool(_slowKey, value);
    // Apply straight away if something is being read.
    if (playback.value == Playback.playing) {
      await pause();
      await resume();
    }
  }

  Future<void> _run() async {
    final session = ++_session;
    final lang = _lang;
    if (lang == null) return;
    playback.value = Playback.playing;
    try {
      await _configure(lang, _voice);
      while (_index < _parts.length) {
        final part = _parts[_index];
        _partStart = _offset.clamp(0, part.length);
        await _tts.speak(part.substring(_partStart));
        if (session != _session) return;
        _index++;
        _offset = 0;
        if (_index < _parts.length) await Future<void>.delayed(const Duration(milliseconds: 700));
        if (session != _session) return;
      }
      playback.value = Playback.idle;
    } catch (_) {
      if (session == _session) playback.value = Playback.idle;
    }
  }

  Future<void> stop() async {
    _session++;
    _parts = const [];
    playback.value = Playback.idle;
    await _tts.stop();
  }
}
