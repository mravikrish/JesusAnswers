import 'package:flutter/widgets.dart';

/// Every language the app ships in. Adding one requires:
///   1. a source in tool/build_bible.dart (then `dart run tool/build_bible.dart`)
///   2. lib/l10n/app_<code>.arb
///   3. an entry here.
class AppLanguage {
  const AppLanguage(this.code, this.nativeName, this.englishName, this.region, {String? speechCode})
      : speechCode = speechCode ?? code;

  final String code;
  final String nativeName;
  final String englishName;
  final String region;

  /// The phone's speech engines' code where it differs from [code]: Tagalog is "fil".
  final String speechCode;

  Locale get locale => Locale(code);

  /// BCP-47 tag used for text-to-speech, e.g. "te-IN".
  String get ttsTag => '$speechCode-$region';

  /// Locale id used by speech_to_text, e.g. "te_IN".
  String get sttId => '${speechCode}_$region';
}

const appLanguages = [
  AppLanguage('en', 'English', 'English', 'IN'),
  AppLanguage('hi', 'हिन्दी', 'Hindi', 'IN'),
  AppLanguage('te', 'తెలుగు', 'Telugu', 'IN'),
  AppLanguage('ta', 'தமிழ்', 'Tamil', 'IN'),
  AppLanguage('kn', 'ಕನ್ನಡ', 'Kannada', 'IN'),
  AppLanguage('ml', 'മലയാളം', 'Malayalam', 'IN'),
  AppLanguage('mr', 'मराठी', 'Marathi', 'IN'),
  AppLanguage('pa', 'ਪੰਜਾਬੀ', 'Punjabi', 'IN'),
  AppLanguage('bn', 'বাংলা', 'Bengali', 'IN'),
  AppLanguage('gu', 'ગુજરાતી', 'Gujarati', 'IN'),
  AppLanguage('or', 'ଓଡ଼ିଆ', 'Odia', 'IN'),
  AppLanguage('es', 'Español', 'Spanish', 'MX'),
  AppLanguage('pt', 'Português', 'Portuguese', 'BR'),
  AppLanguage('fr', 'Français', 'French', 'FR'),
  AppLanguage('sw', 'Kiswahili', 'Swahili', 'KE'),
  AppLanguage('tl', 'Tagalog', 'Tagalog', 'PH', speechCode: 'fil'),
  AppLanguage('de', 'Deutsch', 'German', 'DE'),
  AppLanguage('it', 'Italiano', 'Italian', 'IT'),
  AppLanguage('pl', 'Polski', 'Polish', 'PL'),
  AppLanguage('ru', 'Русский', 'Russian', 'RU'),
  AppLanguage('uk', 'Українська', 'Ukrainian', 'UA'),
];

AppLanguage languageFor(String code) =>
    appLanguages.firstWhere((l) => l.code == code, orElse: () => appLanguages.first);
