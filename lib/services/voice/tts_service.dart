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
    music.value = _prefs.getBool(_musicKey) ?? true;
    prayerMale.value = _prefs.getBool(_prayerMaleKey) ?? false;
    readingMale.value = _prefs.getBool(_readingMaleKey) ?? false;
    playback.addListener(_syncMusic);
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

  /// Soft music under the voice (our own, built by tool/build_music.py):
  /// strings under His words, the piano hymn under everything else.
  /// On unless turned off; saved for next time.
  final music = ValueNotifier(true);

  /// Prayers are read in a man's voice or a woman's, as the user chooses. Saved for next time.
  final prayerMale = ValueNotifier(false);

  /// The Bible and Bible stories are read in a man's voice or a woman's, as the user chooses. Saved for next time.
  final readingMale = ValueNotifier(false);

  /// How far through what is being read, 0–1, word by word.
  final progress = ValueNotifier(0.0);

  /// Which part is being read and where its current word starts — for
  /// highlighting words as they are spoken.
  final position = ValueNotifier((part: 0, offset: 0));

  static const _slowKey = 'ttsSlow';
  static const _musicKey = 'ttsMusic';
  static const _prayerMaleKey = 'prayerMale';
  static const _readingMaleKey = 'readingMale';

  /// How loud the music plays under the voice: quiet enough never to cover a word.
  static const _musicVolume = 0.14;

  /// How loud the welcome music plays while nothing is being read.
  static const _ambientVolume = 0.3;

  /// Played softly in turn from the moment the app opens, while nothing is being read:
  /// public-domain recordings by the U.S. Air Force Band's Strolling Strings (credited in About).
  static const welcomeTracks = ['music/welcome_grace.mp3', 'music/welcome_canon.mp3'];
  int _welcome = 0;

  bool _ambient = false;

  /// Music while nothing is read: on while the app is open and in front, off while it is
  /// away or while the microphone listens. Follows [music] like the music under the voice.
  Future<void> setAmbient(bool on) async {
    if (_ambient == on) return;
    _ambient = on;
    await _syncMusic();
  }
  static const _normalRate = 0.42, _slowRate = 0.32;

  int _session = 0;
  String? _configuredFor;

  /// Downloaded natural voices.
  final NaturalVoiceStore voices;
  final _natural = NaturalSpeech();
  AudioPlayer? _player;
  AudioPlayer? _musicPlayer;
  VoiceRole _role = VoiceRole.verse;

  /// A man's (true) or a woman's (false) voice asked for; null = by [_role].
  bool? _male;

  /// Music and voice play together, and neither interrupts the other.
  static final _mix = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  Future<AudioPlayer> _newPlayer() async {
    final p = AudioPlayer();
    await p.setAudioContext(_mix);
    return p;
  }

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
    final male = override == null ? _male : null;
    final key = '${lang.code}|$wanted|${slow.value}|$male';
    if (_configuredFor == key) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(lang.ttsTag);
    await _tts.setSpeechRate(slow.value ? _slowRate : _normalRate);

    final voices = await voicesFor(lang);
    final saved = voices.where((v) => v.name == wanted);
    final pick = male == null
        ? saved.firstOrNull ?? voices.where((v) => v.male).firstOrNull
        : saved.where((v) => v.male == male).firstOrNull ?? voices.where((v) => v.male == male).firstOrNull;
    // No voice of the wanted kind on this phone: lower or raise the one there is instead.
    await _tts.setPitch(male == null || pick != null ? 0.88 : (male ? 0.72 : 1.15));
    if (pick != null) await _tts.setVoice(pick.toMap());
    _configuredFor = key;
  }

  /// The natural voice for [lang]: a man's or a woman's when [male] is given, else by [role].
  static NaturalVoice? _naturalFor(String lang, VoiceRole role, bool? male) =>
      naturalVoiceFor(lang, male == null ? role : (male ? VoiceRole.jesus : VoiceRole.verse));

  /// The natural voice that would read [lang] for [role] / [male], if it is downloaded.
  Future<bool> hasNaturalVoice(AppLanguage lang, {VoiceRole role = VoiceRole.verse, bool? male}) async {
    final v = _naturalFor(lang.code, role, male);
    return v != null && await voices.isInstalled(v);
  }

  Future<void> setPrayerMale(bool value) async {
    prayerMale.value = value;
    await _prefs.setBool(_prayerMaleKey, value);
  }

  Future<void> setReadingMale(bool value) async {
    readingMale.value = value;
    await _prefs.setBool(_readingMaleKey, value);
  }

  /// Speaks [parts] in order with a gentle pause between each.
  /// [role] picks the natural voice: His words take the male one.
  /// [voice] overrides the saved phone voice (used to preview voices).
  /// [male] asks for a man's or a woman's voice whatever the [role] (prayers, the Bible, stories).
  Future<void> speak(List<String> parts, AppLanguage lang,
      {TtsVoice? voice, VoiceRole role = VoiceRole.verse, bool? male}) async {
    await stop();
    _parts = [for (final p in parts) if (p.trim().isNotEmpty) p];
    _lang = lang;
    _voice = voice;
    _role = role;
    _male = male;
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

  Future<void> setMusic(bool value) async {
    music.value = value;
    await _prefs.setBool(_musicKey, value);
    await _syncMusic();
  }

  /// The music follows the reading: plays while it plays, pauses with it, and after it goes back
  /// to the welcome music while the app is open.
  /// One change at a time, so quick pause/resume taps never start it twice.
  Future<void> _syncMusic() => _musicSync = _musicSync.then((_) => _applyMusic());
  Future<void> _musicSync = Future.value();
  String? _musicTrack;

  /// The music player; when a welcome piece ends, the next one begins.
  Future<AudioPlayer> _newMusicPlayer() async {
    final player = await _newPlayer();
    player.onPlayerComplete.listen((_) {
      if (playback.value != Playback.idle) return;
      _welcome++;
      _syncMusic();
    });
    return player;
  }

  Future<void> _applyMusic() async {
    try {
      final reading = playback.value;
      final idle = reading == Playback.idle;
      if (!music.value || (idle && !_ambient)) {
        await _musicPlayer?.stop();
        return;
      }
      final player = _musicPlayer ??= await _newMusicPlayer();
      final track =
          idle ? welcomeTracks[_welcome % welcomeTracks.length] : (_role == VoiceRole.jesus ? 'music/pad.mp3' : 'music/hymn.mp3');
      if (track != _musicTrack) {
        // Reading starts or ends, or a reading with the other voice: change the music with it.
        await player.stop();
        _musicTrack = track;
      }
      await player.setVolume(idle ? _ambientVolume : _musicVolume);
      if (reading == Playback.paused) {
        await player.pause();
      } else if (player.state == PlayerState.paused) {
        await player.resume();
      } else if (player.state != PlayerState.playing) {
        // The welcome pieces play one after another; the music under a voice loops.
        await player.setReleaseMode(idle ? ReleaseMode.stop : ReleaseMode.loop);
        await player.play(AssetSource(track));
      }
    } catch (_) {
      // Music is a nicety: if it can't play, the reading goes on without it.
    }
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
    final natural = _voice == null ? _naturalFor(lang.code, _role, _male) : null;
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

  /// Loads the natural voice for [lang] and [role], if downloaded, so the first
  /// Listen starts at once. Screens that read aloud call this when they open.
  Future<void> warmUp(AppLanguage lang, {VoiceRole role = VoiceRole.verse, bool? male}) async {
    final voice = _naturalFor(lang.code, role, male);
    final files = voice == null ? null : await voices.files(voice);
    if (files == null) return;
    try {
      await _natural.warmUp(model: files.model, tokens: files.tokens, dataDir: files.dataDir);
    } catch (_) {
      // Not loadable here: speaking falls back to the phone's voice anyway.
    }
  }

  /// Reads the remaining parts with a natural voice, a sentence at a time:
  /// the first sentence plays as soon as it is ready while the next is
  /// prepared, so there is no long wait and no gap. The current word follows
  /// how far the audio has played, since the engine gives no word timings.
  Future<void> _runNatural(int session, NaturalVoice voice, ({String model, String tokens, String dataDir}) files) async {
    final player = _player ??= await _newPlayer();
    final dir = (await getTemporaryDirectory()).path;
    final scale = voice.lengthScale * (slow.value ? 1.2 : 1);

    // Everything still to read, as (part, start offset in it, text), sentence by sentence.
    final chunks = <(int, int, String)>[
      for (var i = _index; i < _parts.length; i++)
        for (final (start, text) in sentences(_parts[i], from: i == _index ? _offset.clamp(0, _parts[i].length) : 0))
          (i, start, text),
    ];
    var made = 0;
    Future<(String, double)> prepare(int k) async {
      final path = '$dir/voice_${session}_${made++}.wav';
      final seconds = await _natural.synthesize(
        model: files.model,
        tokens: files.tokens,
        dataDir: files.dataDir,
        text: chunks[k].$3,
        lengthScale: scale,
        wavPath: path,
      );
      return (path, seconds);
    }

    Future<(String, double)>? next = chunks.isEmpty ? null : prepare(0);
    for (var k = 0; k < chunks.length; k++) {
      final (part, start, text) = chunks[k];
      final (path, seconds) = await next!;
      if (session != _session) return;
      next = k + 1 < chunks.length ? prepare(k + 1) : null;
      if (part != _index) {
        // A new part: the pause between parts, as with the phone's voice.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (session != _session) return;
      }
      _index = part;
      _partStart = start;
      _offset = start;
      _report();

      final finished = Completer<void>();
      final subs = [
        player.onPlayerComplete.listen((_) {
          if (!finished.isCompleted) finished.complete();
        }),
        player.onPositionChanged.listen((p) {
          if (session != _session || seconds <= 0) return;
          final at = (text.length * p.inMilliseconds / (seconds * 1000)).round().clamp(0, text.length);
          final space = text.lastIndexOf(' ', at);
          _offset = start + (space < 0 ? 0 : space + 1);
          _report();
        }),
      ];
      await player.play(DeviceFileSource(path));
      // Stopped while it was starting: make sure it is silent.
      if (session != _session) await player.stop();
      // Paused or stopped: the player is stopped, so stop waiting too.
      while (!finished.isCompleted && session == _session) {
        await Future.any([finished.future, Future<void>.delayed(const Duration(milliseconds: 250))]);
      }
      for (final s in subs) {
        await s.cancel();
      }
      unawaited(File(path).delete().catchError((_) => File(path)));
      if (session != _session) return;
    }
    _index = _parts.length;
    _offset = 0;
    _report();
    playback.value = Playback.idle;
  }

  /// [text] from [from] split into sentences of a comfortable length, as
  /// (start offset, sentence). Long sentences break at a comma, then a space.
  @visibleForTesting
  static List<(int, String)> sentences(String text, {int from = 0}) {
    const maxLength = 220;
    final out = <(int, String)>[];
    final ends = RegExp(r'[.!?;:।॥。]+["”’»)]*\s+');
    var start = from;
    void add(int a, int b) {
      while (b - a > maxLength) {
        final window = text.substring(a, a + maxLength);
        var cut = window.lastIndexOf(RegExp(r'[,،、]\s'));
        if (cut < maxLength ~/ 3) cut = window.lastIndexOf(' ');
        if (cut <= 0) cut = maxLength - 1;
        out.add((a, text.substring(a, a + cut + 1).trim()));
        a += cut + 1;
        while (a < b && text[a] == ' ') {
          a++;
        }
      }
      final piece = text.substring(a, b).trim();
      if (piece.isNotEmpty) out.add((a, piece));
    }

    for (final m in ends.allMatches(text, from)) {
      add(start, m.end);
      start = m.end;
    }
    add(start, text.length);
    // Very short pieces ("Amen.") join the one before, so the voice keeps its flow.
    final merged = <(int, String)>[];
    for (final (a, piece) in out) {
      if (merged.isNotEmpty && piece.length < 25 && merged.last.$2.length + piece.length < maxLength) {
        merged.last = (merged.last.$1, text.substring(merged.last.$1, a + piece.length).trim());
      } else {
        merged.add((a, piece));
      }
    }
    return merged;
  }
}
