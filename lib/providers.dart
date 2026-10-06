import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/languages.dart';
import 'data/bible/bible_repository.dart';
import 'data/models/answer.dart';
import 'data/models/painting.dart';
import 'data/models/prayer.dart';
import 'data/models/story.dart';
import 'data/models/verse.dart';
import 'l10n/app_localizations.dart';
import 'services/answer/answer_service.dart';
import 'services/community_service.dart';
import 'services/days_service.dart';
import 'services/feedback/feedback_service.dart';
import 'services/reminder_service.dart';
import 'services/voice/natural_voices.dart';
import 'services/voice/speech_service.dart';
import 'services/voice/tts_service.dart';

/// Set at launch: `flutter run --dart-define=API_BASE_URL=https://api.example.com`
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('overridden in main'));

final bibleProvider = Provider((_) => BibleRepository());
final ttsProvider = Provider((ref) {
  final prefs = ref.read(prefsProvider);
  return TtsService(prefs, voices: NaturalVoiceStore(sources: VoiceSources(prefs, baseUrl: apiBaseUrl)));
});
final speechProvider = Provider((_) => SpeechService());

/// Hearts, and what other people loved, prayed and listened to. Counts are fetched at most hourly.
final communityProvider = Provider((ref) {
  final community = CommunityService(ref.read(prefsProvider), baseUrl: apiBaseUrl);
  community.refresh();
  ref.onDispose(community.dispose);
  return community;
});
/// Days with Jesus, kept on the phone.
final daysProvider = Provider((ref) {
  final days = DaysService(ref.read(prefsProvider));
  ref.onDispose(days.dispose);
  return days;
});
final reminderServiceProvider = Provider((_) => ReminderService());
final feedbackServiceProvider = Provider((_) => FeedbackService());

/// Keeps the daily reminder to spend time with God in step with its time and the app language.
/// Watched by the app root, so it also re-schedules on every launch.
final reminderSyncProvider = Provider<void>((ref) {
  final (lang, minute) = ref.watch(settingsProvider.select((s) => (s.lang, s.reminder)));
  final l = lookupAppLocalizations(Locale(lang));
  ref
      .read(reminderServiceProvider)
      .sync(minute, title: l.reminderTitle, bodies: [
        l.reminder1,
        l.reminder2,
        l.reminder3,
        l.reminder4,
        l.reminder5,
        l.reminder6,
        l.reminder7,
      ])
      .ignore();
});

final answerServiceProvider = Provider<AnswerService>((ref) {
  final bible = ref.watch(bibleProvider);
  final local = LocalAnswerService(bible);
  return apiBaseUrl.isEmpty ? local : RemoteAnswerService(apiBaseUrl, bible, local);
});

/// A single verse (by language-neutral ref) in the user's current language.
final verseProvider = FutureProvider.family<Verse?, String>((ref, verseRef) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).verse(verseRef, lang);
});

/// Today's verse in the user's current language.
final dailyVerseProvider = FutureProvider<Verse>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).dailyVerse(DateTime.now(), lang);
});

/// All Bible Stories, in reading order.
final storiesProvider = FutureProvider<List<Story>>((ref) => ref.watch(bibleProvider).stories());

/// One story's passages in the user's current language.
final storyPassagesProvider = FutureProvider.family<List<StoryPassage>, Story>((ref, story) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).storyPassages(story, lang);
});

/// The ready prayers, by group, in the user's current language.
final prayerGroupsProvider = FutureProvider<List<PrayerGroup>>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).prayerGroups(lang);
});

/// A Scripture prayer's words ("PSA 23:1-6") in the user's current language.
final prayerPassageProvider = FutureProvider.family<PrayerPassage?, String>((ref, passage) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).prayerPassage(passage, lang);
});

/// All 66 books of the Bible, in the user's current language.
final bibleBooksProvider = FutureProvider<List<BibleBook>>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).bibleBooks(lang);
});

/// The books of the Words of Jesus reader, in the user's current language.
final jesusBooksProvider = FutureProvider<List<BibleBook>>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).jesusBooks(lang);
});

/// One chapter of the Bible: (book code, chapter).
final chapterProvider = FutureProvider.family<List<NumberedVerse>, (String, int)>((ref, at) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).chapter(at.$1, at.$2, lang);
});

/// Today's painting of Jesus (changes every day).
final dailyPaintingProvider = FutureProvider<Painting>((_) => Painting.forDay(DateTime.now()));

/// Where a screen's own painting sits in the collection, away from Home's.
enum PaintingSpot { pray, journey, profile, readyPrayers }

/// Each main screen opens on a painting of its own, different from Home's and from each other's,
/// changing every day along with Home's.
final screenPaintingProvider = FutureProvider.family<Painting, PaintingSpot>((_, spot) async {
  final all = await Painting.all();
  // Spread through the collection, so neighbouring screens don't show neighbouring pictures.
  final step = all.length ~/ (PaintingSpot.values.length + 1);
  return all[(Painting.indexForDay(DateTime.now(), all.length) + step * (spot.index + 1)) % all.length];
});

/// Every picture of Jesus, for the Pictures gallery.
final paintingsProvider = FutureProvider<List<Painting>>((_) => Painting.all());

/// The verse printed on gallery picture [index], in the user's language. Each picture keeps
/// its own verse, taken from the Daily Word list two weeks apart so neighbours differ.
final pictureVerseProvider = FutureProvider.family<Verse, int>((ref, index) {
  final lang = ref.watch(settingsProvider.select((s) => s.lang));
  return ref.watch(bibleProvider).dailyVerse(DateTime(2025).add(Duration(days: index * 15)), lang);
});

// ── Settings ────────────────────────────────────────────────────────────────

class Settings {
  const Settings({
    required this.lang,
    required this.name,
    required this.phone,
    required this.languageChosen,
    this.onboarded = false,
    this.voice = '',
    this.textScale = 1.0,
    this.reminder,
  });
  final String lang;
  final String name;

  /// E.164, e.g. "+919876543210". Empty until the user signs in.
  final String phone;
  final bool languageChosen;

  /// Has seen the three welcome pages.
  final bool onboarded;

  /// TTS voice name chosen for [lang]; empty = automatic (a male voice when the device has one).
  final String voice;

  /// Multiplies the phone's own font size: 1.0, 1.15 or 1.3.
  final double textScale;

  /// Daily Word reminder time as minutes after midnight; null = off.
  final int? reminder;

  bool get signedIn => name.isNotEmpty && phone.isNotEmpty;

  AppLanguage get language => languageFor(lang);

  Settings copyWith({
    String? lang,
    String? name,
    String? phone,
    bool? languageChosen,
    bool? onboarded,
    String? voice,
    double? textScale,
    int? Function()? reminder,
  }) =>
      Settings(
        lang: lang ?? this.lang,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        languageChosen: languageChosen ?? this.languageChosen,
        onboarded: onboarded ?? this.onboarded,
        voice: voice ?? this.voice,
        textScale: textScale ?? this.textScale,
        reminder: reminder != null ? reminder() : this.reminder,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  Settings build() {
    final saved = _prefs.getString('lang');
    final device = PlatformDispatcher.instance.locale.languageCode;
    final lang = saved ?? languageFor(device).code;
    return Settings(
      lang: lang,
      name: _prefs.getString('name') ?? '',
      phone: _prefs.getString('phone') ?? '',
      languageChosen: saved != null,
      // People who chose a language before the welcome pages existed don't need them.
      onboarded: _prefs.getBool('onboarded') ?? saved != null,
      voice: _prefs.getString(TtsService.voiceKey(lang)) ?? '',
      textScale: _prefs.getDouble('textScale') ?? 1.0,
      reminder: _prefs.getInt('reminder'),
    );
  }

  Future<void> setLanguage(String code) async {
    await _prefs.setString('lang', code);
    state = state.copyWith(lang: code, languageChosen: true, voice: _prefs.getString(TtsService.voiceKey(code)) ?? '');
  }

  Future<void> finishOnboarding() async {
    await _prefs.setBool('onboarded', true);
    state = state.copyWith(onboarded: true);
  }

  /// Saves the TTS voice for the current language; null = back to automatic.
  Future<void> setVoice(String? name) async {
    final key = TtsService.voiceKey(state.lang);
    name == null ? await _prefs.remove(key) : await _prefs.setString(key, name);
    state = state.copyWith(voice: name ?? '');
  }

  Future<void> setTextScale(double scale) async {
    await _prefs.setDouble('textScale', scale);
    state = state.copyWith(textScale: scale);
  }

  /// [minuteOfDay] after midnight, or null to turn the reminder off.
  Future<void> setReminder(int? minuteOfDay) async {
    minuteOfDay == null ? await _prefs.remove('reminder') : await _prefs.setInt('reminder', minuteOfDay);
    state = state.copyWith(reminder: () => minuteOfDay);
  }

  Future<void> setName(String name) async {
    await _prefs.setString('name', name.trim());
    state = state.copyWith(name: name.trim());
  }

  Future<void> signIn({required String name, required String phone}) async {
    await _prefs.setString('name', name.trim());
    await _prefs.setString('phone', phone);
    state = state.copyWith(name: name.trim(), phone: phone);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ── My Journey ──────────────────────────────────────────────────────────────

class JourneyNotifier extends Notifier<List<Answer>> {
  static const _key = 'journey';
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  List<Answer> build() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [for (final j in jsonDecode(raw) as List) Answer.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  void add(Answer a) => _save([a, ...state.where((e) => e.id != a.id)]);

  void remove(String id) => _save([for (final a in state) if (a.id != id) a]);

  /// Puts a removed entry back in its place (undo).
  void restore(Answer a) =>
      _save([...state.where((e) => e.id != a.id), a]..sort((x, y) => y.createdAt.compareTo(x.createdAt)));

  void toggleFavorite(String id) =>
      _save([for (final a in state) a.id == id ? a.copyWith(favorite: !a.favorite) : a]);

  Answer? byId(String id) => state.where((a) => a.id == id).firstOrNull;

  void _save(List<Answer> list) {
    state = list.take(500).toList();
    _prefs.setString(_key, jsonEncode([for (final a in state) a.toJson()]));
  }
}

final journeyProvider = NotifierProvider<JourneyNotifier, List<Answer>>(JourneyNotifier.new);
