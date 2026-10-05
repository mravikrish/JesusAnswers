import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_or.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('gu'),
    Locale('hi'),
    Locale('it'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('or'),
    Locale('pa'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('sw'),
    Locale('ta'),
    Locale('te'),
    Locale('tl'),
    Locale('uk'),
  ];

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'JesusAnswers'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'You ask. His Word answers.'**
  String get tagline;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get greetingEvening;

  /// No description provided for @howAreYou.
  ///
  /// In en, this message translates to:
  /// **'How are you today?'**
  String get howAreYou;

  /// No description provided for @tapToTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk to Jesus'**
  String get tapToTalk;

  /// No description provided for @tapToTalkHint.
  ///
  /// In en, this message translates to:
  /// **'Tell me what\'s on your heart'**
  String get tapToTalkHint;

  /// No description provided for @typeHint.
  ///
  /// In en, this message translates to:
  /// **'Or type what\'s on your heart…'**
  String get typeHint;

  /// No description provided for @howAreYouFeeling.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get howAreYouFeeling;

  /// No description provided for @peaceNow.
  ///
  /// In en, this message translates to:
  /// **'Peace Now'**
  String get peaceNow;

  /// No description provided for @dailyWord.
  ///
  /// In en, this message translates to:
  /// **'Daily Word'**
  String get dailyWord;

  /// No description provided for @prayForMe.
  ///
  /// In en, this message translates to:
  /// **'Pray for Me'**
  String get prayForMe;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navWord.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get navWord;

  /// No description provided for @navTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get navTalk;

  /// No description provided for @navPray.
  ///
  /// In en, this message translates to:
  /// **'Pray'**
  String get navPray;

  /// No description provided for @navJourney.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get navJourney;

  /// No description provided for @moodTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you feeling today?'**
  String get moodTitle;

  /// No description provided for @moodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a topic or tell me directly.'**
  String get moodSubtitle;

  /// No description provided for @moodWorried.
  ///
  /// In en, this message translates to:
  /// **'Worried'**
  String get moodWorried;

  /// No description provided for @moodSad.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get moodSad;

  /// No description provided for @moodAfraid.
  ///
  /// In en, this message translates to:
  /// **'Afraid'**
  String get moodAfraid;

  /// No description provided for @moodAngry.
  ///
  /// In en, this message translates to:
  /// **'Angry'**
  String get moodAngry;

  /// No description provided for @moodHurt.
  ///
  /// In en, this message translates to:
  /// **'Hurt'**
  String get moodHurt;

  /// No description provided for @moodLonely.
  ///
  /// In en, this message translates to:
  /// **'Lonely'**
  String get moodLonely;

  /// No description provided for @moodLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get moodLost;

  /// No description provided for @moodTired.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get moodTired;

  /// No description provided for @moodNeedStrength.
  ///
  /// In en, this message translates to:
  /// **'Need Strength'**
  String get moodNeedStrength;

  /// No description provided for @moodNeedHope.
  ///
  /// In en, this message translates to:
  /// **'Need Hope'**
  String get moodNeedHope;

  /// No description provided for @moodGrateful.
  ///
  /// In en, this message translates to:
  /// **'Grateful'**
  String get moodGrateful;

  /// No description provided for @moodCantSleep.
  ///
  /// In en, this message translates to:
  /// **'Can\'t Sleep'**
  String get moodCantSleep;

  /// No description provided for @moodOther.
  ///
  /// In en, this message translates to:
  /// **'Other (tell me)'**
  String get moodOther;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Jesus is listening…'**
  String get listening;

  /// No description provided for @listeningHint.
  ///
  /// In en, this message translates to:
  /// **'Speak freely. Tell Him everything on your heart.'**
  String get listeningHint;

  /// No description provided for @micUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input isn\'t available right now. You can type instead.'**
  String get micUnavailable;

  /// No description provided for @processingTitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding your heart…'**
  String get processingTitle;

  /// No description provided for @stepAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your message'**
  String get stepAnalyzing;

  /// No description provided for @stepFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding relevant Bible verses'**
  String get stepFinding;

  /// No description provided for @stepPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing encouragement'**
  String get stepPreparing;

  /// No description provided for @stepPrayer.
  ///
  /// In en, this message translates to:
  /// **'Creating a prayer for you'**
  String get stepPrayer;

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your Answer'**
  String get yourAnswer;

  /// No description provided for @youAsked.
  ///
  /// In en, this message translates to:
  /// **'You asked'**
  String get youAsked;

  /// No description provided for @godsWord.
  ///
  /// In en, this message translates to:
  /// **'God\'s Word for You'**
  String get godsWord;

  /// No description provided for @encouragement.
  ///
  /// In en, this message translates to:
  /// **'Encouragement'**
  String get encouragement;

  /// No description provided for @aPrayerForYou.
  ///
  /// In en, this message translates to:
  /// **'A Prayer for You'**
  String get aPrayerForYou;

  /// No description provided for @playAnswer.
  ///
  /// In en, this message translates to:
  /// **'Play Answer'**
  String get playAnswer;

  /// No description provided for @playPrayer.
  ///
  /// In en, this message translates to:
  /// **'Play Prayer'**
  String get playPrayer;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @openingLine.
  ///
  /// In en, this message translates to:
  /// **'My friend, take a breath. Here is what God\'s Word says to you.'**
  String get openingLine;

  /// No description provided for @notAlone.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to face this moment alone.'**
  String get notAlone;

  /// No description provided for @prayTitle.
  ///
  /// In en, this message translates to:
  /// **'Pray With Me'**
  String get prayTitle;

  /// No description provided for @prayPrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like prayer for?'**
  String get prayPrompt;

  /// No description provided for @prayHint.
  ///
  /// In en, this message translates to:
  /// **'Type your prayer request here…'**
  String get prayHint;

  /// No description provided for @speakFreely.
  ///
  /// In en, this message translates to:
  /// **'Speak freely'**
  String get speakFreely;

  /// No description provided for @generatePrayer.
  ///
  /// In en, this message translates to:
  /// **'Generate Prayer'**
  String get generatePrayer;

  /// No description provided for @todaysWord.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Word'**
  String get todaysWord;

  /// No description provided for @todaysMessage.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Message'**
  String get todaysMessage;

  /// No description provided for @dailyEncouragement.
  ///
  /// In en, this message translates to:
  /// **'Before you begin your day, remember: you are not walking alone. Let this Word guide your steps today.'**
  String get dailyEncouragement;

  /// No description provided for @peaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a deep breath. Let God\'s Word calm your heart.'**
  String get peaceSubtitle;

  /// No description provided for @breatheIn.
  ///
  /// In en, this message translates to:
  /// **'Breathe In'**
  String get breatheIn;

  /// No description provided for @breatheOut.
  ///
  /// In en, this message translates to:
  /// **'Breathe Out'**
  String get breatheOut;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String seconds(int count);

  /// No description provided for @prayWithMe.
  ///
  /// In en, this message translates to:
  /// **'Pray With Me'**
  String get prayWithMe;

  /// No description provided for @journeyTitle.
  ///
  /// In en, this message translates to:
  /// **'My Journey'**
  String get journeyTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get filterQuestions;

  /// No description provided for @filterPrayers.
  ///
  /// In en, this message translates to:
  /// **'Prayers'**
  String get filterPrayers;

  /// No description provided for @filterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get filterFavorites;

  /// No description provided for @journeyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your journey begins with your first question.'**
  String get journeyEmpty;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @friend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get friend;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @voiceMale.
  ///
  /// In en, this message translates to:
  /// **'Male (calm)'**
  String get voiceMale;

  /// No description provided for @scriptureSource.
  ///
  /// In en, this message translates to:
  /// **'Scripture source'**
  String get scriptureSource;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About JesusAnswers'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'JesusAnswers uses AI to help you find encouragement and relevant teachings from the Bible. Scripture is quoted word-for-word from published translations. Reflections and prayers are AI-generated and are not a substitute for pastoral, medical or professional care.'**
  String get aboutBody;

  /// No description provided for @crisisTitle.
  ///
  /// In en, this message translates to:
  /// **'You matter, and you are not alone.'**
  String get crisisTitle;

  /// No description provided for @crisisBody.
  ///
  /// In en, this message translates to:
  /// **'It sounds like you may be going through something very painful. Please reach out to someone right now — a person you trust, or a helpline.'**
  String get crisisBody;

  /// No description provided for @crisisIndia.
  ///
  /// In en, this message translates to:
  /// **'India — Tele-MANAS (free, 24×7): 14416'**
  String get crisisIndia;

  /// No description provided for @crisisUS.
  ///
  /// In en, this message translates to:
  /// **'USA — call or text 988'**
  String get crisisUS;

  /// No description provided for @crisisEmergency.
  ///
  /// In en, this message translates to:
  /// **'If you are in immediate danger, call your local emergency number (112 in India).'**
  String get crisisEmergency;

  /// No description provided for @crisisFind.
  ///
  /// In en, this message translates to:
  /// **'Find a helpline in your country'**
  String get crisisFind;

  /// No description provided for @genericEncouragement.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry this alone. God sees you, knows your situation, and is with you in every step. Take one day at a time, and trust Him with what you cannot control.'**
  String get genericEncouragement;

  /// No description provided for @genericPrayer.
  ///
  /// In en, this message translates to:
  /// **'Lord Jesus, I bring my heart before You. Give me Your peace, Your strength and Your wisdom for what I am facing. Help me to trust You, even when I cannot see the way ahead. Thank You for always being with me. Amen.'**
  String get genericPrayer;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us a little about you so we can greet you by name.'**
  String get signInSubtitle;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get nameRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid mobile number.'**
  String get phoneInvalid;

  /// No description provided for @homeInvite.
  ///
  /// In en, this message translates to:
  /// **'He is here with you. Tell Him what\'s on your heart.'**
  String get homeInvite;

  /// No description provided for @keepTalking.
  ///
  /// In en, this message translates to:
  /// **'Keep talking to Him…'**
  String get keepTalking;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @dayOfYear.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String dayOfYear(int day, int total);

  /// No description provided for @downloadApp.
  ///
  /// In en, this message translates to:
  /// **'Download the app:'**
  String get downloadApp;

  /// No description provided for @entryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from your journey'**
  String get entryRemoved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get dailyReminder;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Word is waiting for you.'**
  String get reminderBody;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @micPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is turned off. Allow it in Settings to talk by voice, or type instead.'**
  String get micPermission;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @micLanguage.
  ///
  /// In en, this message translates to:
  /// **'This phone can\'t understand spoken {language} yet. Add it in voice settings, or type instead.'**
  String micLanguage(String language);

  /// No description provided for @voiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice settings'**
  String get voiceSettings;

  /// No description provided for @micNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t hear you. Tap the mic to try again, or type instead.'**
  String get micNoSpeech;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @typeInstead.
  ///
  /// In en, this message translates to:
  /// **'Type instead'**
  String get typeInstead;

  /// No description provided for @noVoice.
  ///
  /// In en, this message translates to:
  /// **'This phone has no voice for {language}, so nothing can be read aloud.'**
  String noVoice(String language);

  /// No description provided for @downloadVoice.
  ///
  /// In en, this message translates to:
  /// **'Download voice'**
  String get downloadVoice;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @speakSlower.
  ///
  /// In en, this message translates to:
  /// **'Slower'**
  String get speakSlower;

  /// No description provided for @copyVerse.
  ///
  /// In en, this message translates to:
  /// **'Copy verse'**
  String get copyVerse;

  /// No description provided for @shareVerse.
  ///
  /// In en, this message translates to:
  /// **'Share verse'**
  String get shareVerse;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @searchJourney.
  ///
  /// In en, this message translates to:
  /// **'Search your journey'**
  String get searchJourney;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search.'**
  String get noMatches;

  /// No description provided for @topicWorry.
  ///
  /// In en, this message translates to:
  /// **'Worry & fear'**
  String get topicWorry;

  /// No description provided for @topicWork.
  ///
  /// In en, this message translates to:
  /// **'Work & money'**
  String get topicWork;

  /// No description provided for @topicFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get topicFamily;

  /// No description provided for @topicSorrow.
  ///
  /// In en, this message translates to:
  /// **'Sadness & loss'**
  String get topicSorrow;

  /// No description provided for @topicHealth.
  ///
  /// In en, this message translates to:
  /// **'Health & rest'**
  String get topicHealth;

  /// No description provided for @topicGuidance.
  ///
  /// In en, this message translates to:
  /// **'Guidance'**
  String get topicGuidance;

  /// No description provided for @topicForgiveness.
  ///
  /// In en, this message translates to:
  /// **'Forgiveness'**
  String get topicForgiveness;

  /// No description provided for @topicFaith.
  ///
  /// In en, this message translates to:
  /// **'Faith & hope'**
  String get topicFaith;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what would make it better'**
  String get feedbackHint;

  /// No description provided for @feedbackIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us what helped, what was confusing, or what you\'d like added. Type, or tap the mic to speak.'**
  String get feedbackIntro;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @feedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your message has reached us.'**
  String get feedbackThanks;

  /// No description provided for @feedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Please check your internet and try again.'**
  String get feedbackFailed;

  /// No description provided for @onboardTitle1.
  ///
  /// In en, this message translates to:
  /// **'Find peace, strength and answers in His Word.'**
  String get onboardTitle1;

  /// No description provided for @onboardBody1.
  ///
  /// In en, this message translates to:
  /// **'Scripture, encouragement and prayer for whatever you are facing.'**
  String get onboardBody1;

  /// No description provided for @onboardTitle2.
  ///
  /// In en, this message translates to:
  /// **'Ask anything from your heart.'**
  String get onboardTitle2;

  /// No description provided for @onboardBody2.
  ///
  /// In en, this message translates to:
  /// **'Speak or type. Receive Bible verses, encouragement and a prayer for your situation.'**
  String get onboardBody2;

  /// No description provided for @onboardTitle3.
  ///
  /// In en, this message translates to:
  /// **'You are not alone.'**
  String get onboardTitle3;

  /// No description provided for @onboardBody3.
  ///
  /// In en, this message translates to:
  /// **'Let God\'s Word guide you every step of the way.'**
  String get onboardBody3;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @begin.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get begin;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// No description provided for @trackOf.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String trackOf(int current, int total);

  /// No description provided for @bibleStories.
  ///
  /// In en, this message translates to:
  /// **'Bible Stories'**
  String get bibleStories;

  /// No description provided for @bibleStoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Told in the Bible\'s own words'**
  String get bibleStoriesSubtitle;

  /// No description provided for @oldTestament.
  ///
  /// In en, this message translates to:
  /// **'Old Testament'**
  String get oldTestament;

  /// No description provided for @newTestament.
  ///
  /// In en, this message translates to:
  /// **'New Testament'**
  String get newTestament;

  /// No description provided for @picturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pictures of Jesus'**
  String get picturesTitle;

  /// No description provided for @picturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save one, or share it as your WhatsApp status'**
  String get picturesSubtitle;

  /// No description provided for @whatsappStatus.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Status'**
  String get whatsappStatus;

  /// No description provided for @savePicture.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savePicture;

  /// No description provided for @verseOnPicture.
  ///
  /// In en, this message translates to:
  /// **'Verse'**
  String get verseOnPicture;

  /// No description provided for @pictureSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get pictureSaved;

  /// No description provided for @pictureSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please allow access to photos.'**
  String get pictureSaveFailed;

  /// No description provided for @wordsOfJesus.
  ///
  /// In en, this message translates to:
  /// **'Words of Jesus'**
  String get wordsOfJesus;

  /// No description provided for @wordsOfJesusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything He said, in red letters'**
  String get wordsOfJesusSubtitle;

  /// No description provided for @onlyHisWords.
  ///
  /// In en, this message translates to:
  /// **'Only His words'**
  String get onlyHisWords;

  /// No description provided for @holyBible.
  ///
  /// In en, this message translates to:
  /// **'Holy Bible'**
  String get holyBible;

  /// No description provided for @holyBibleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read any book, any chapter'**
  String get holyBibleSubtitle;

  /// No description provided for @readChapter.
  ///
  /// In en, this message translates to:
  /// **'Read the whole chapter'**
  String get readChapter;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @pictures.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get pictures;

  /// No description provided for @booksOfTheBible.
  ///
  /// In en, this message translates to:
  /// **'Books of the Bible'**
  String get booksOfTheBible;

  /// No description provided for @shareStory.
  ///
  /// In en, this message translates to:
  /// **'Share story'**
  String get shareStory;

  /// No description provided for @getItOnGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Get it on Google Play'**
  String get getItOnGooglePlay;

  /// No description provided for @hearHimSpeak.
  ///
  /// In en, this message translates to:
  /// **'Hear Him speak'**
  String get hearHimSpeak;

  /// No description provided for @illustration.
  ///
  /// In en, this message translates to:
  /// **'Illustration'**
  String get illustration;

  /// No description provided for @naturalVoices.
  ///
  /// In en, this message translates to:
  /// **'Natural voices'**
  String get naturalVoices;

  /// No description provided for @naturalVoicesHint.
  ///
  /// In en, this message translates to:
  /// **'Free voices that sound more natural. Download once and they work offline. Wi-Fi recommended.'**
  String get naturalVoicesHint;

  /// No description provided for @voiceOfJesus.
  ///
  /// In en, this message translates to:
  /// **'Voice of Jesus'**
  String get voiceOfJesus;

  /// No description provided for @verseReader.
  ///
  /// In en, this message translates to:
  /// **'Verse reader'**
  String get verseReader;

  /// No description provided for @downloadVoiceSize.
  ///
  /// In en, this message translates to:
  /// **'Download · {size} MB'**
  String downloadVoiceSize(int size);

  /// No description provided for @removeVoice.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeVoice;

  /// No description provided for @voiceDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download. Check your internet and try again.'**
  String get voiceDownloadFailed;

  /// No description provided for @voiceCredits.
  ///
  /// In en, this message translates to:
  /// **'Voice credits'**
  String get voiceCredits;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @readyPrayers.
  ///
  /// In en, this message translates to:
  /// **'Ready Prayers'**
  String get readyPrayers;

  /// No description provided for @readyPrayersHint.
  ///
  /// In en, this message translates to:
  /// **'Prayers for every day and every need. Tap one to hear it.'**
  String get readyPrayersHint;

  /// No description provided for @voiceMan.
  ///
  /// In en, this message translates to:
  /// **'Male voice'**
  String get voiceMan;

  /// No description provided for @voiceWoman.
  ///
  /// In en, this message translates to:
  /// **'Female voice'**
  String get voiceWoman;

  /// No description provided for @sharePrayer.
  ///
  /// In en, this message translates to:
  /// **'Share prayer'**
  String get sharePrayer;

  /// No description provided for @searchPrayers.
  ///
  /// In en, this message translates to:
  /// **'Search prayers'**
  String get searchPrayers;

  /// No description provided for @forMe.
  ///
  /// In en, this message translates to:
  /// **'For me'**
  String get forMe;

  /// No description provided for @forSomeone.
  ///
  /// In en, this message translates to:
  /// **'For someone'**
  String get forSomeone;

  /// No description provided for @forSomeoneHint.
  ///
  /// In en, this message translates to:
  /// **'Type their name and the prayer is written for them, ready to send.'**
  String get forSomeoneHint;

  /// No description provided for @theirName.
  ///
  /// In en, this message translates to:
  /// **'Their name'**
  String get theirName;

  /// No description provided for @theirNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name of the person you are praying for'**
  String get theirNameHint;

  /// No description provided for @enterNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Type their name first'**
  String get enterNameFirst;

  /// No description provided for @noPrayersFound.
  ///
  /// In en, this message translates to:
  /// **'No prayers found'**
  String get noPrayersFound;

  /// No description provided for @whatsappMessage.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappMessage;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'de',
    'en',
    'es',
    'fr',
    'gu',
    'hi',
    'it',
    'kn',
    'ml',
    'mr',
    'or',
    'pa',
    'pl',
    'pt',
    'ru',
    'sw',
    'ta',
    'te',
    'tl',
    'uk',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'or':
      return AppLocalizationsOr();
    case 'pa':
      return AppLocalizationsPa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'sw':
      return AppLocalizationsSw();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'tl':
      return AppLocalizationsTl();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
