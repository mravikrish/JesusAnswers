# JesusAnswers

*You ask. His Word answers.*

A Flutter app (Android + iOS) that listens to what's on someone's heart and responds with
**Scripture → Encouragement → Prayer**, read aloud in a calm voice, in 21 languages.

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
| es   | Español   | Reina-Valera 1909 (public domain) * |
| pt   | Português | Bíblia Portuguesa Mundial (public domain) |
| fr   | Français  | Louis Segond 1910 (public domain) |
| sw   | Kiswahili | Neno: Biblia Takatifu, Biblica (CC BY-SA 4.0) |
| tl   | Tagalog   | Tagalog ULB, Door43 (CC BY-SA 4.0) * |
| de   | Deutsch   | Lutherbibel 1912 (public domain) * |
| it   | Italiano  | Riveduta 1927 (public domain) * |
| pl   | Polski    | Uwspółcześniona Biblia Gdańska (CC BY-ND 4.0: never altered, as with every text here) * |
| ru   | Русский   | Синодальный перевод (public domain) * |
| uk   | Українська | Kulish–Puluj 1905 (public domain) |

\* These sources don't mark the words of Jesus, so their red letters are placed from the KJV's: each KJV span
is set at the same point of the verse and moved to the nearest colon or quotation mark (start) and sentence end
(finish). The words are always the translation's own; only where the red falls is approximate.

**Verse numbering.** Every ref in the app uses KJV numbering. Some sources number differently (Louis Segond's
Psalms follow the Hebrew; the Synodal follows the Septuagint), so the build renumbers each chapter with the
Paratext versification maps in `tool/bible/versification/` (from SIL's libpalaso, MIT licence), choosing per
chapter whichever of "as is", Hebrew or Synodal numbering gives the KJV's verse count. A few chapters still
differ by a merged verse, as in the IRV; French Job 39–41 and Spanish Job 39–41 keep their own numbering.

**Not yet:** Korean (the only public-domain Bible on eBible.org, 1910, is missing whole passages, e.g. all of
1 Peter 5) and Amharic (New Testament only, and commercial use needs the Bible Society of Ethiopia's
permission).

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
Christmas). Feb 29 repeats Feb 28. Every ref is checked complete in all 21 translations; some IRV editions
merge adjacent verses, so refs that are merged in any language were swapped out.

**The whole Bible.** The build also writes `assets/bible/full/<lang>.json.gz`: all 66 books in each
translation, gzipped (about 1.2–1.7 MB each, 31 MB for all 21), for the Holy Bible reader. The app unpacks a
language off the UI thread the first time it is opened. The backend doesn't need it and leaves it out.

**Book pictures.** In the Holy Bible screen each book is a picture card; tapping one shows its key verse
and chapters. `tool/bible/books.json` lists every book's key verse (checked present in all 21 translations by
the build) and a `scene` describing its picture. Put originals in `art/books/<CODE>.png|jpg` (e.g. `GEN.png`,
`1SA.jpg`; kept out of git like `art/stories/`) and run `python tool/build_story_images.py`. A book with no
picture yet shows its Bible Story's picture, or else a painting of Jesus.

**Hear Him speak.** Words of Jesus (and any chapter where He speaks) can play His words over a living portrait
(`art/portrait/jesus_speaking.png` → `assets/portrait/jesus_speaking.jpg`): a slow drift, a faint breath, light
that glows while He speaks, and each word lighting up as the phone's male voice reaches it. Only Scripture is
spoken — His red-letter words, verbatim — never anything generated, and the screen is labelled "Illustration".
The famous sayings it plays are `famousSayings` in `speak_screen.dart`. Next steps: a consistent neural voice
(pre-generated audio), then lip-synced video for chosen sayings.

**Natural voices (free).** Profile → Natural voices downloads free Piper voices that then speak offline on the
phone, through sherpa-onnx (`lib/services/voice/natural_voices.dart`, `natural_speech.dart`). His words use the
male "Voice of Jesus"; verses, stories and everything else the female "Verse reader"; a language or role
without one keeps the phone's voice. Files come uncompressed from the sherpa-onnx authors' Hugging Face copies
(`csukuangfj/vits-piper-<voice>`): a shared 17 MB pronunciation folder once, then 20–110 MB per voice. Every
voice is licensed for app use (CC0, public domain, CC BY, CC BY-SA, Apache); credits are under Profile →
Voice credits. Chosen voices: male Northern English, Ald (es), Faber (pt), Gilles (fr), Thorsten (de),
Darkman (pl), Denis (ru); female Cori (en), Daniela (es), Siwis (fr), Kerstin (de), Gosia (pl), Lada (uk).
Telugu, Bengali, Marathi and Ukrainian male voices exist but aren't hosted in converted form yet.

**Background music.** Soft music plays under anything read aloud: a strings pad under His words (the male
voice) and "Amazing Grace" on piano (public domain tune) under everything else (the female voice). Both are
composed by `tool/build_music.py` into `assets/music/`, so they are the app's own: no licence, no credit. A
Music toggle sits beside Slower and is remembered.

**Name under the icon.** Launchers show about nine letters, so "JesusAnswers" became "JesusAn…". The icon
label is **Ask Jesus** (`android:label`, iOS `CFBundleDisplayName`); the app's name stays JesusAnswers
everywhere else — the store listing, splash screen, recent apps and shared pictures.

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
  core/languages.dart          the 21 languages (TTS/STT locale tags)
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
- [ ] Native-speaker review of the 10 new languages (es pt fr sw tl de it pl ru uk): app text, story titles,
      book names (Russian and some Tagalog/Ukrainian names are overrides in `book_name_overrides.json`).
- [ ] Ukrainian: the Kulish–Puluj text (1905) uses «жид/жидовин» for Jews, now offensive in modern Ukrainian.
      Decide whether to ship it or seek permission for a modern translation (e.g. Ohienko).
- [ ] Crisis helplines are shown by the phone's country (`_helplines` in `common.dart`); have someone in each
      country confirm the number before launching there.
- [ ] Natural voices: try each on a mid-range Android phone (speed, memory) before release; host converted
      Telugu, Bengali, Marathi and Ukrainian male voices (e.g. on Hugging Face) to add them.
- [ ] Replace device TTS with a neural cloud voice for a consistent warm male voice in Indian languages.
- [ ] Firebase (Auth, Analytics, FCM for the Daily Word notification). Not wired yet. Sign-in currently
      stores name + mobile number on the device only; add OTP (Firebase Phone Auth) in `sign_in_screen.dart`.
- [ ] Own pictures for the 14 books that borrow a story picture (GEN EXO JOS RUT 1SA 1KI EST DAN JON MAT MRK LUK JHN ACT).
- [ ] Native-speaker check of the book names new with the full Bible (19 books, mostly Old Testament).
- [ ] Native-speaker check of the Words of Jesus strings ("Words of Jesus", "Only His words").
- [ ] Native-speaker check of the new conversational strings ("Jesus is listening…", "Talk to Jesus").
