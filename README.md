# JesusAnswers

*You ask. His Word answers.*

A Flutter app (Android + iOS) that listens to what's on someone's heart and responds with
**Scripture → Encouragement → Prayer**, read aloud in a calm voice, in 11 languages.

## Run

```bash
flutter pub get
flutter run                                              # offline mode
flutter run --dart-define=API_BASE_URL=https://api.example.com   # with the AI backend
flutter test
```

## Languages

| Code | Language  | Scripture          |
|------|-----------|--------------------|
| en   | English   | KJV (public domain) |
| hi   | हिन्दी      | IRV (CC BY-SA 4.0) |
| te   | తెలుగు     | IRV                |
| ta   | தமிழ்      | IRV                |
| kn   | ಕನ್ನಡ      | IRV                |
| ml   | മലയാളം    | IRV                |
| mr   | मराठी      | IRV                |
| pa   | ਪੰਜਾਬੀ      | IRV                |
| bn   | বাংলা      | IRV                |
| gu   | ગુજરાતી     | IRV                |
| or   | ଓଡ଼ିଆ       | IRV                |

IRV = Indian Revised Version © Bridge Connectivity Solutions, via eBible.org. CC BY-SA 4.0 requires
attribution (shown in Profile → Scripture source) and share-alike for the *verse text*.

## The one rule: never invent Scripture

```
tool/bible/themes.json          language-neutral index: "MAT 6:34" → [anxiety, work, …]
        │  dart run tool/build_bible.dart   (downloads from eBible.org, verbatim)
        ▼
assets/bible/<lang>.json        verse text + localized book names, per language
```

The AI may **choose** verse references; it never supplies verse text. The app renders text only
from the bundled corpus, so a reference that doesn't exist is dropped.

To add verses: add refs + themes to `tool/bible/themes.json` and re-run the build tool.

**Daily Word — 365 verses.** `tool/bible/daily.json` holds one reference per day (Jan 1 → Dec 31), grouped
by month with a theme (Jan *New beginnings*, Feb *God's love*, … Dec *Emmanuel*, with Luke 2:10–11 on
Christmas). Feb 29 repeats Feb 28. Every ref is checked complete in all 11 translations; some IRV editions
merge adjacent verses, so refs that are merged in any language were swapped out.

**The whole Bible.** The build also writes `assets/bible/full/<lang>.json.gz`: all 66 books in each
translation, gzipped (about 1.6 MB each, 17 MB for all 11), for the Holy Bible reader. The app unpacks a
language off the UI thread the first time it is opened. The backend doesn't need it and leaves it out.

**Book pictures.** In the Holy Bible screen each book is a picture card; tapping one shows its key verse
and chapters. `tool/bible/books.json` lists every book's key verse (checked present in all 11 translations by
the build) and a `scene` describing its picture. Put originals in `art/books/<CODE>.png|jpg` (e.g. `GEN.png`,
`1SA.jpg`; kept out of git like `art/stories/`) and run `python tool/build_story_images.py`. A book with no
picture yet shows its Bible Story's picture, or else a painting of Jesus.

**Sharing pictures.** Every picture in the app — of Jesus, of each Bible Story, of each book — can be sent as a
WhatsApp status from Home → Pictures, or from the story or book itself. Story and book art (landscape, title
painted in) sits whole at the top of the 9:16 card over a blurred copy of itself, with its name and, for books,
the key verse beneath. A story's text can also be shared on its own (Share story).

**Words of Jesus.** Each translation's USFM marks His words with `\wj … \wj*`. The build lines those up with
the verse text and stores them as character ranges under `wj` (in both the quoted verses and the full Bible),
so the app shows them in red: in the Bible and Words of Jesus readers, and wherever a verse appears. A few
sources close `\wj` late, after the narration; a span that opens with “ is ended at its matching ”.

## Daily painting of Jesus

Home opens on a different public-domain painting each day (Carl Bloch, Heinrich Hofmann, Bernhard
Plockhorst, Gebhard Fugel — all pre-1930, via Wikimedia Commons). It also appears in the listening orb and
beside His Word in the answer conversation.

```
tool/paintings/sources.json     curated list + focus point (where His face is)
        │  python tool/fetch_paintings.py   (needs Pillow; slow — Commons rate-limits)
        ▼
assets/jesus/NN.jpg + paintings.json   (with license + source page for each)
```

Only gentle scenes are used for the daily greeting — no crucifixion or burial scenes.

## Code map

```
lib/
  core/languages.dart          the 11 languages (TTS/STT locale tags)
  data/bible/                  BibleRepository: retrieval by theme, daily verse
  services/answer/
    answer_service.dart        LocalAnswerService (offline) · RemoteAnswerService (backend)
    safety.dart                crisis detection in every supported language
    theme_classifier.dart      offline keyword → theme
  services/voice/              speech-to-text, calm male TTS
  features/                    home, mood, talk (listen/processing), answer, prayer,
                               daily_word, peace, journey, profile, welcome (language)
  l10n/app_<lang>.arb          UI strings
```

## Backend contract (Spring Boot + LLM)

`POST /v1/answers`

```json
{ "question": "I lost my job", "lang": "te", "mood": "afraid", "kind": "question" }
```

```json
{ "themes": ["work", "fear"], "verseRefs": ["MAT 6:34", "ISA 41:10"],
  "encouragement": "…in Telugu…", "prayer": "…in Telugu…", "crisis": false }
```

Server guidance:
- Give the LLM the theme index (`themes.json`) and require `verseRefs` to come from it.
- Generate encouragement and prayer **in `lang`**, warm and brief, and never put words in Jesus' mouth.
- Classify risk. On `crisis: true` the app shows helplines (Tele-MANAS 14416, 988, 112) before Scripture.

If the backend fails or times out, the app falls back to `LocalAnswerService` automatically.

## Release build

The debug APK is ~214 MB (it carries every CPU architecture plus debugging support). Share release builds instead:

```bash
flutter build apk --release --split-per-abi   # one APK per CPU type, in build/app/outputs/flutter-apk/
flutter build appbundle --release             # for the Play Store: Google sends each phone only what it needs
```

| APK | Size | For |
|-----|------|-----|
| `app-arm64-v8a-release.apk`   | ~26 MB | almost every phone from the last 6–7 years — share this one |
| `app-armeabi-v7a-release.apk` | ~24 MB | older and low-cost 32-bit phones |
| `app-x86_64-release.apk`      | ~28 MB | emulators and Chromebooks |

**Signing.** Release builds use `android/key.properties` when it exists, and the debug key otherwise (fine for
testing, but it can't be published). Create the key once and keep it safe — every update must be signed with it:

```bash
keytool -genkey -v -keystore ~/jesusanswers-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

```properties
# android/key.properties (git-ignored)
storeFile=C:/Users/you/jesusanswers-upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

## Before release

- [ ] **Native-speaker review of every `app_<lang>.arb`.** I drafted these translations; a fluent
      Christian reader for each language should check tone and church vocabulary.
- [ ] Review `tool/bible/book_name_overrides.json` (Marathi, Punjabi, Gujarati short names).
- [ ] Have a native speaker check the crisis keywords in `safety.dart` for each language.
- [ ] Replace device TTS with a neural cloud voice for a consistent warm male voice in Indian languages.
- [ ] Firebase (Auth, Analytics, FCM for the Daily Word notification). Not wired yet. Sign-in currently
      stores name + mobile number on the device only; add OTP (Firebase Phone Auth) in `sign_in_screen.dart`.
- [ ] Own pictures for the 14 books that borrow a story picture (GEN EXO JOS RUT 1SA 1KI EST DAN JON MAT MRK LUK JHN ACT).
- [ ] Native-speaker check of the book names new with the full Bible (19 books, mostly Old Testament).
- [ ] Native-speaker check of the Words of Jesus strings ("Words of Jesus", "Only His words").
- [ ] Native-speaker check of the new conversational strings ("Jesus is listening…", "Talk to Jesus").
