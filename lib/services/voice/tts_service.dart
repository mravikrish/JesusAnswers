import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/languages.dart';
import 'natural_speech.dart';
import 'natural_voices.dart';

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
/// Speaks with a downloaded natural voice when there is one for the language
/// and [VoiceRole] (see natural_voices.dart), otherwise with the device's TTS
/// engine (offline in every supported language once its voice data is installed).
class TtsService {
  TtsService(this._prefs, {NaturalVoiceStore? voices}) : voices = voices ?? NaturalVoiceStore() {
    slow.value = _prefs.getBool(_slowKey) ?? false;
    // Remember where we are in the current part, so Pause → Resume carries on from that word.
    _tts.setProgressHandler((_, start, _, _) {
      _offset = _partStart + start;
      _report();
    });
  }

  final SharedPreferences _prefs;
  final _tts = FlutterTts();

  final playback = ValueNotifier(Playback.idle);

  /// Read more slowly than the normal calm pace. Saved for next time.
  final slow = ValueNotifier(false);

  /// How far through what is being read, 0–1, word by word.
  final progress = ValueNotifier(0.0);

  /// Which part is being read and where its current word starts — for
  /// highlighting words as they are spoken.
  final position = ValueNotifier((part: 0, offset: 0));

  static const _slowKey = 'ttsSlow';
  static const _normalRate = 0.42, _slowRate = 0.32;

  int _session = 0;
  String? _configuredFor;

  /// Downloaded natural voices.
  final NaturalVoiceStore voices;
  final _natural = NaturalSpeech();
  AudioPlayer? _player;
  VoiceRole _role = VoiceRole.verse;

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
  /// [role] picks the natural voice: His words take the male one.
  /// [voice] overrides the saved phone voice (used to preview voices).
  Future<void> speak(List<String> parts, AppLanguage lang, {TtsVoice? voice, VoiceRole role = VoiceRole.verse}) async {
    await stop();
    _parts = [for (final p in parts) if (p.trim().isNotEmpty) p];
    _lang = lang;
    _voice = voice;
    _role = role;
    _index = 0;
    _offset = 0;
    _report();
    await _run();
  }

  /// Jumps to [fraction] (0–1) of what is being read, at the start of that word.
  /// Keeps playing if it was; otherwise Resume carries on from there.
  Future<void> seek(double fraction) async {
    if (_parts.isEmpty) return;
    var target = (fraction.clamp(0.0, 1.0) * _parts.fold(0, (n, p) => n + p.length)).round();
    var i = 0;
    while (i < _parts.length - 1 && target >= _parts[i].length) {
      target -= _parts[i].length;
      i++;
    }
    final space = _parts[i].lastIndexOf(' ', target.clamp(0, _parts[i].length));
    _index = i;
    _offset = space < 0 ? 0 : space + 1;
    _report();
    if (playback.value == Playback.playing) {
      _session++;
      await _tts.stop();
      await _player?.stop();
      await _run();
    } else {
      playback.value = Playback.paused; // Finished or paused: Resume starts from the new place.
    }
  }

  void _report() {
    position.value = (part: _index, offset: _offset);
    final total = _parts.fold(0, (n, p) => n + p.length);
    if (total == 0) return;
    final done = _parts.take(_index).fold(0, (n, p) => n + p.length) + _offset;
    progress.value = (done / total).clamp(0.0, 1.0);
  }

  /// Stops mid-sentence; [resume] carries on from the same word.
  Future<void> pause() async {
    if (playback.value != Playback.playing) return;
    _session++;
    playback.value = Playback.paused;
    await _tts.stop();
    await _player?.stop();
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
    final natural = _voice == null ? naturalVoiceFor(lang.code, _role) : null;
    final files = natural == null ? null : await voices.files(natural);
    if (natural != null && files != null) {
      try {
        await _runNatural(session, natural, files);
      } catch (_) {
        // A natural voice that fails falls back to the phone's voice, from where it got to.
        if (session == _session) await _runDevice(++_session, lang);
      }
      return;
    }
    await _runDevice(session, lang);
  }

  Future<void> _runDevice(int session, AppLanguage lang) async {
    try {
      await _configure(lang, _voice);
      while (_index < _parts.length) {
        final part = _parts[_index];
        _partStart = _offset.clamp(0, part.length);
        await _tts.speak(part.substring(_partStart));
        if (session != _session) return;
        _index++;
        _offset = 0;
        _report();
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
    progress.value = 0;
    position.value = (part: 0, offset: 0);
    playback.value = Playback.idle;
    await _tts.stop();
    await _player?.stop();
  }

  /// Reads the remaining parts with a natural voice. The next part is prepared
  /// while this one plays, so there are no gaps; the current word is followed
  /// by how far the audio has played, since the engine gives no word timings.
  Future<void> _runNatural(int session, NaturalVoice voice, ({String model, String tokens, String dataDir}) files) async {
    final player = _player ??= AudioPlayer();
    final dir = (await getTemporaryDirectory()).path;
    final scale = voice.lengthScale * (slow.value ? 1.2 : 1);
    Future<(String, double)> prepare(int index, int from) async {
      final path = '$dir/voice_${session}_$index.wav';
      final text = _parts[index].substring(from);
      final seconds = await _natural.synthesize(
        model: files.model,
        tokens: files.tokens,
        dataDir: files.dataDir,
        text: text,
        lengthScale: scale,
        wavPath: path,
      );
      return (path, seconds);
    }

    var next = prepare(_index, _offset.clamp(0, _parts[_index].length));
    while (_index < _parts.length) {
      final part = _parts[_index];
      _partStart = _offset.clamp(0, part.length);
      final (path, seconds) = await next;
      if (session != _session) return;
      if (_index + 1 < _parts.length) next = prepare(_index + 1, 0);

      final finished = Completer<void>();
      final spoken = part.substring(_partStart);
      final subs = [
        player.onPlayerComplete.listen((_) {
          if (!finished.isCompleted) finished.complete();
        }),
        player.onPositionChanged.listen((p) {
          if (session != _session || seconds <= 0) return;
          final at = (spoken.length * p.inMilliseconds / (seconds * 1000)).round().clamp(0, spoken.length);
          final space = spoken.lastIndexOf(' ', at);
          _offset = _partStart + (space < 0 ? 0 : space + 1);
          _report();
        }),
      ];
      await player.play(DeviceFileSource(path));
      // Paused or stopped: the player is stopped, so stop waiting too.
      while (!finished.isCompleted && session == _session) {
        await Future.any([finished.future, Future<void>.delayed(const Duration(milliseconds: 250))]);
      }
      for (final s in subs) {
        await s.cancel();
      }
      unawaited(File(path).delete().catchError((_) => File(path)));
      if (session != _session) return;
      _index++;
      _offset = 0;
      _report();
      if (_index < _parts.length) await Future<void>.delayed(const Duration(milliseconds: 600));
      if (session != _session) return;
    }
    playback.value = Playback.idle;
  }
}
