<p align="center">
  <img src="docs/icon.png" width="128" alt="Fuyu app icon" />
</p>

<h1 align="center">Fuyu</h1>

<p align="center">A faster way to get through your WaniKani reviews.</p>

<p align="center">
  <img src="docs/screenshots/home.png" width="215" alt="Home dashboard" />
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/review.png" width="215" alt="Review session" />
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/kanji-progress.png" width="215" alt="Kanji progress grid" />
</p>

[WaniKani](https://www.wanikani.com) is a web-based Japanese kanji learning platform that uses spaced repetition (SRS) to teach radicals, kanji, and vocabulary.

The further you progress the easier it is for reviews to pile up, and missing a day might mean you come back to hundreds of reviews waiting. The WaniKani website and mobile web uses keyboard input only and is also strict about what it accepts for answers; exact meanings, particular phrasing for vocabulary, a typo or a close but wrong answer counts as incorrect and every mistake keeps you from progressing. It becomes time consuming and starts to feel impossible to catch up.

Fuyu is an iOS app built to fix that. It swaps the type-in input for multiple choice so there are no typos and you can move through reviews much faster. The goal is  to make it feel more manageable enough that you actually want to sit down and do them. It connects to WaniKani through their official API using your own API key, so your reviews and lessons always pull from your real account and results are submitted back as you go.

---

## Features

### Review session

This is the core of the app and where you'll spend most of your time. Reviews are how your WaniKani progress actually moves forward.

Each item gets two cards, one for meaning and one for reading, because WaniKani only counts an item as correct when you get both right. Miss either and it slips back down its SRS stage, exactly as it would on the site. The two cards are mixed into the queue rather than shown back to back, so answering the reading isn't just recalling the card you saw a second ago.

Each card gives you four choices. After answering you see the correct meaning and reading, any component radicals or kanji, example sentences for vocabulary, and the mnemonic. An item is sent to WaniKani as soon as both of its cards are answered, so leaving halfway through keeps everything you finished.

The queue leads with the kanji from the level you're on, then kanji held over from earlier levels, then your current level's vocabulary, then vocabulary from further back, with radicals last. Kanji are what everything above them is built from, and a backlog is rarely cleared in one sitting, so the order decides what actually gets done.

**Blurred choices.** Kanji and vocabulary sitting at Master or Enlightened haven't come around in a month or more, and having four options in front of you the moment the card appears turns recall into recognition. Those cards open with the choices blurred behind a **Show Answers** button, so you answer in your head first and then check. Everything below Master is shown normally.

**Easy Mode** is an optional toggle in Settings that drops the reading card entirely. Kanji and vocabulary become meaning-only, the way radicals already are, and the reading is submitted as correct so your real SRS still advances on the meaning answer alone. It roughly halves the number of cards in a backlog.

In Easy Mode a vocabulary card also breaks the word into its kanji, listed under the card in the order they appear in the word, each with its meaning. Tapping one opens that kanji's own card as a popup, with its readings, radicals and mnemonic, without leaving the question.

Easy Mode vocabulary cards also show the word's reading in hiragana, with a speaker button beside the card that reads it aloud. Speech runs on-device using the best Japanese voice installed. The built-in one is fairly robotic, so it's worth downloading an Enhanced or Premium Japanese voice under **Settings → Accessibility → Spoken Content → Voices**, which the app picks up automatically. Apple doesn't let apps use the Siri voices themselves.

### Lesson session

A lesson is where you learn an item for the first time. Rather than being quizzed, you're shown the radical, kanji, or vocabulary word along with its meaning, its reading, how it breaks down into components, and example sentences for vocabulary. Once you move past it, the item is added to your reviews and starts coming back on the SRS schedule.

Items come in the order WaniKani introduces them: lowest level first, and within a level, radicals before kanji before vocabulary. That order matters, because radicals build the kanji and kanji build the vocabulary, so you meet the pieces before the things made out of them.

Each item is sent to WaniKani the moment you tap Next, so you don't have to get through everything in one sitting. Whatever you didn't reach is still waiting as a lesson the next time you come back.

### Home dashboard

The first screen after signing in. A daily goal ring tracks how many reviews you've done today against how many came due, and resets at midnight. Below it, the lesson and review tiles show what's waiting right now, and when nothing is due, when the next reviews arrive. Pull down to refresh.

The **Reading Practice** card generates a sentence around a vocabulary word from your current level, as a quick bit of reading between sessions. It uses the same sentence sources, known-kanji highlighting and translate button as the example sentences below.

### Example sentences

Vocabulary items can show a Japanese example sentence using the target word, with Apple's translation sheet a tap away. The sentence is selectable text, so the system **Look Up**, **Translate** and **Copy** menu works on any part of it. Four sources are supported, switchable under **Settings → AI Model**:

| Source | Notes |
|---|---|
| **Pre-generated** | Bundled database covering ~6,500 vocabulary words across all 60 levels. Instant, offline, no model required. |
| **Claude API** | Bring your own Anthropic API key. Highest quality; the only one that generates on demand. |
| **Apple On-Device AI** | Apple Foundation Models, iOS 26+, on-device, no download. |
| **Qwen2.5-3B** | ~2 GB download, runs fully offline after that. |

Sentences generated by Claude are appended to a writable overlay in Application Support and merged back into the pre-generated pool at read time, so the offline database grows as you use the app.

Generated sentences are built from one of 135 grammar prompts spanning N5 to N1, and each retry picks a fresh one. A sentence is only accepted if the target word actually appears in it, conjugated or not. The app makes up to five attempts and, if none work out, falls back to a pre-generated sentence rather than showing an error.

**Sentences you can read.** An example sentence isn't much use if half its kanji are ones you haven't learned. A kanji counts as known once it reaches Master on WaniKani, and the target word's own kanji always count. Every source prefers sentences built from what you know: the generators keep whichever attempt has the fewest unknown kanji, stopping early on one that has none, and the pre-generated pool serves its most readable sentence for the word instead of a random one. It's best effort rather than strict, since at low levels almost every sentence has something new in it.

Kanji that aren't at Master yet are underlined in gold in the sentence and in the **Kanji in sentence** strip beneath it. Tap one to open its card, with readings, radicals and mnemonic.

With Apple On-Device AI, the model can also call a tool while writing that looks up vocabulary you have at Master or above, optionally around a topic it picks, and build the rest of the sentence from those words.

**Grammar help.** With the Claude backend, an example sentence can be explained: which grammar it uses and how the sentence is put together, followed by a chat thread for follow-up questions about it.

> **Note on the local models.** Apple Foundation Models triggers safety guardrails on a large number of vocabulary words, blocking generation entirely. Qwen2.5 produces consistent sentences, but they're often not grammatically correct or natural sounding, and hallucinates to korean for some reason. The pre-generated database was built from larger models running off-device to route around both, and is the recommended default. Sentences through level 17 come from Claude Opus; the rest were produced with gemma3 through [wanikani-sentence-generator](https://github.com/armanizuniga/wanikani-sentence-generator), filtered so the target word actually appears in the sentence.

### Kanji Review and Vocab Review

These two are practice, and only practice. Each is a self-quiz you can run whenever you want over material you've already learned, using the same multiple-choice cards as a real review but without touching your WaniKani account. They're the same feature over different subjects: Kanji Review quizzes your kanji, Vocab Review quizzes your vocabulary, including kana-only words.

Your subjects are grouped by SRS stage: Apprentice, Guru, Master, Enlightened, and Burned. The setup screen lists how many you have sitting in each stage, which is a useful picture on its own of where you actually stand. Pick any combination of stages and the app builds a session of 15 from that pool. Every card here opens with its choices blurred behind a **Show Answers** button, since the whole mode is recall practice on material you've already learned.

Nothing here is sent to WaniKani. Answers don't change your SRS stages, don't count toward your daily goal, and don't consume anything from your review queue. It exists mainly for burned and enlightened items, which WaniKani treats as finished and won't show you again, but which are exactly the ones that quietly fade.

**Burned items get their own schedule.** WaniKani retires a burned item permanently, so the app keeps a local SRS of its own over everything it sees burned on your account. Kanji and vocabulary are tracked on separate schedules, so a session in one never draws from or scores against the other. Intervals run 1, 3, 7, 14, 30, 90 and 180 days. A newly burned item is queued immediately so it's never quietly filed away, a correct answer pushes it further out, and a miss drops it back two stages. Resurrect something on WaniKani and it leaves this queue, since the real SRS has it again.

Sessions over the burned pool lead with items you've never practiced here, then the ones you're weakest at. Weakness is measured on a smoothed accuracy, so an item answered once doesn't outrank one with a long record either way, and due date only breaks ties. The point is to spend a short session on what's actually fading rather than on whatever happened to wait longest.

**Burned Stats**, linked from each setup screen, is the record behind that: how far each burned item has been pushed out, which ones you still miss, and which are solid. Something you've missed sits under Needs Work with a count of how many correct answers are left to clear it, and four right in a row moves it back across to Strongest, marked as recovered. All of it is local and none of it exists on WaniKani.

### Lock Screen widget

An accessory widget for the Lock Screen that cycles through vocabulary you've passed, showing the word, its reading, and its meaning. It changes over the course of the day. Available in both the rectangular and inline families.

Burned vocabulary is used first. Those words are gone from WaniKani reviews for good, so the Lock Screen is the only place they'll turn up again. Passed vocabulary backs it up, and early-level words back that up, so a new account still sees something.

The app writes a small word pool into a shared App Group container; the widget reads from that file, so it works with no network access and never touches the app's database. The pool is refreshed on launch and whenever pass and burn status are synced from WaniKani.

### Siri and Shortcuts

The main actions are available to Siri, Spotlight, the Shortcuts app and the Action button with no setup. Open the app once and they're registered.

| Say | What happens |
|---|---|
| "How many reviews do I have in Fuyu?" | Answers with your review and lesson counts, or when the next reviews arrive, without opening the app |
| "Start my Fuyu reviews" / "…lessons" | Opens straight into the session |
| "Quiz me on burned kanji in Fuyu" / "…burned vocab" | Opens Kanji Review or Vocab Review |
| "Look up a word in Fuyu" | Asks which word, then shows its meaning, reading and level |
| "Explain a word in Fuyu" | Meaning, reading, the kanji or radicals it's built from, its mnemonic and an example sentence |
| "Say a word in Fuyu" | Reads it aloud with the same voice as the speaker button |

Your kanji and vocabulary are also searchable from the Home Screen: search by the kanji, the reading or an English meaning and tap a result to open its card in the app. Only items at or below your current level are indexed, so search never shows you material you haven't reached. The index is rebuilt when your level changes, and otherwise once a week.

**On-screen awareness (iOS 27).** With the new Siri, the item currently on screen can be referred to directly: "explain this word" or "say this" while a review, practice or lesson card or an item's detail card is open. Siri only reads what's on screen at the moment you invoke it. Nothing is sent to it otherwise.

### Name Practice

Japanese names use readings that often aren't the ones WaniKani teaches. 中 is なか in 田中 rather than ちゅう, and some names use nanori readings that appear nowhere else in the language. WaniKani never covers this, so names stay hard to read long after the kanji themselves are easy.

Practice runs over the 100 most common surnames, a set of common given names, or full names built by pairing the two, which is how you'd actually meet them. Answer, and the reveal shows the reading in hiragana and romaji, a per-kanji breakdown of how the reading maps on, and what you already know each kanji as from WaniKani, so the contrast is visible.

Readings come from [JMnedict](https://www.edrdg.org/enamdict/enamdict_doc.html) cross-checked against published frequency rankings. Nothing is composed at runtime: name readings are irregular enough that a generated name couldn't be quizzed honestly, since 愛 alone has 52 attested readings. Like Kanji Review and Vocab Review, nothing here touches your WaniKani account.

### Kana practice

A standalone hiragana and katakana practice mode with its own SRS, separate from WaniKani. Each character has a mastery level that goes up as you get it right and drops when you get it wrong. Characters you struggle with show up more often until you've got them down.

### Kanji progress

A scrollable grid of every WaniKani kanji grouped by level. Passed kanji are shown in pink; unlearned ones are greyed out. Pass status is synced from WaniKani assignments at launch and updated locally after each review submission.

### Level detail

A breakdown of your current level showing radicals, kanji, and vocabulary grouped into passed, in-progress, and not-started, with each item showing how far along it is in the SRS.

### Offline support

All subjects are stored on your device so the app works even without a connection. On first launch they're loaded from a built-in database of ~9,000 WaniKani subjects. Your account data is refreshed in the background each time you open the app, and a banner lets you know if you lose connection mid-session.

WaniKani periodically reshuffles which level a kanji or vocabulary word belongs to, and retires subjects outright. To keep up, the app pulls whatever has changed since its last sync. That runs once a day in the background, so it's normally a single small request. **Settings → Sync Subjects** forces it and shows when the last one landed.

> **Planned.** Full offline review and lesson support is something we want to add. The idea is to let you complete reviews and lessons normally while offline, save the results locally, and automatically sync everything back to WaniKani once your connection is restored. That way being without internet is never a reason to skip a session.

---

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| Widget | WidgetKit + App Group shared container |
| AI (cloud) | Claude API (`claude-haiku-4-5`) |
| AI (on-device) | MLXLLM (Qwen2.5-3B-Instruct-4bit) |
| AI (system) | Apple FoundationModels (iOS 26+), including tool calling |
| Siri and Spotlight | App Intents + Core Spotlight |
| Speech | AVSpeechSynthesizer |
| API | WaniKani API v2 |
| Auth | Keychain via Security framework |

Both the WaniKani token and the optional Anthropic key are stored in the Keychain under separate accounts. Neither is ever written to disk in plaintext or bundled with the app.

---

## Data and backup

Everything the app knows lives on your device. There's no account, no server, no analytics, and nothing is sent anywhere except WaniKani's API, and the Claude API if you supply a key.

**There is no iCloud sync.** The app declares no iCloud entitlement and SwiftData runs with a local store, so installing on a second device starts it from scratch. Reviews and lessons stay in step across devices only because they're submitted to WaniKani; anything the app tracks itself does not.

What a nightly iCloud Backup does and doesn't capture:

| Data | Backed up |
|---|---|
| Subject database, kana SRS progress | Yes |
| Claude-generated sentences | Yes |
| Settings, cached user, daily goal | Yes |
| WaniKani and Anthropic API keys | Yes, in the Keychain, encrypted and restorable to a new device |
| Qwen2.5 model (~2 GB) | No, stored in Caches |
| Bundled subject and sentence databases | No, they ship inside the app |

Three consequences worth knowing:

- **Signing out clears this device only.** **Settings → Sign Out** removes the WaniKani token from the Keychain, forgets the cached account, empties the widget's word pool, and removes your items from the on-device Spotlight index. Your subjects and kana progress stay, and nothing on WaniKani changes. The Claude key is separate, and you remove it under **Settings → AI Model**.
- **Your kana progress exists nowhere else.** WaniKani has no concept of it, so unlike your SRS stages it can't be re-fetched. iCloud Backup is the only thing protecting it.
- **The Qwen model can vanish.** `Caches` is kept out of backups deliberately, since a 2 GB model has no business in one. iOS may also purge it under storage pressure, in which case it needs downloading again.

---

## Project structure

```
WaniKaniHelper/
├── WaniKaniHelper/
│   ├── WaniKaniHelperApp.swift       — app entry, auth routing, bootstrap, subject and widget sync
│   ├── Models/
│   │   ├── Subject.swift             — CachedSubject SwiftData model
│   │   ├── ReviewItem.swift          — ReviewItem struct, QuestionType enum
│   │   ├── KanaSRSEntry.swift        — KanaSRSEntry SwiftData model
│   │   ├── SRSCategory.swift         — SRS-stage groupings shared by both practice modes
│   │   ├── PracticeKind.swift        — kanji vs. vocabulary, and the copy that differs
│   │   ├── BurnedSRSEntry.swift      — protocol plus the kanji and vocab SwiftData records
│   │   ├── BurnedStat.swift          — value snapshot and ranking rules for Burned Stats
│   │   └── JapaneseName.swift        — name entry, reading, and per-kanji segments
│   ├── Services/
│   │   ├── WaniKaniAPI.swift         — API client, all endpoints, response types
│   │   ├── ReviewService.swift       — review session state, Easy Mode, submission
│   │   ├── LessonService.swift       — lesson session state
│   │   ├── PracticeReviewService.swift — local-only kanji and vocab practice, never submits
│   │   ├── KanaReviewService.swift   — kana session state and grading
│   │   ├── KanaData.swift            — static hiragana/katakana tables
│   │   ├── NameStore.swift           — loads the bundled name list
│   │   ├── NamePracticeService.swift — name quiz state and distractors
│   │   ├── BundledSentenceStore.swift — pre-generated sentence database
│   │   ├── SavedSentenceStore.swift  — writable overlay for newly generated sentences
│   │   ├── SentenceStore.swift       — loads sentences.json for static examples
│   │   ├── SentenceGeneratorService.swift  — AI generation for home card
│   │   ├── ExampleGeneratorService.swift   — AI generation for review/lesson
│   │   ├── PromptLibrary.swift       — selects grammar prompts by user level
│   │   ├── KnownKanji.swift          — Master+ kanji and vocab, most-readable-sentence selection
│   │   ├── JapaneseSpeaker.swift     — on-device Japanese speech for the speaker button
│   │   ├── WidgetWordSync.swift      — writes the widget word pool to the App Group
│   │   ├── SubjectBundler.swift      — BundledSubject Codable struct for bundle import
│   │   ├── KeychainService.swift     — API key storage
│   │   ├── DailyGoal.swift           — daily review count, resets at midnight
│   │   └── AI/
│   │       ├── AIBackend.swift       — AIGeneratedContent struct, AIBackend protocol
│   │       ├── AIModelManager.swift  — backend selection and download lifecycle
│   │       ├── ClaudeBackend.swift   — Claude Messages API, BYO key
│   │       ├── MLCQwenBackend.swift  — Qwen2.5 via MLXLLM
│   │       ├── AppleFoundationBackend.swift — FoundationModels backend (iOS 26+)
│   │       └── KnownVocabularyTool.swift — tool the Apple model calls to find known words
│   ├── Intents/                      — Siri, Spotlight and Shortcuts
│   │   ├── ReviewIntents.swift       — Check Reviews, Start Reviews / Lessons / Burned Practice
│   │   ├── SubjectEntity.swift       — kanji and vocab as App Entities, search, Spotlight index
│   │   ├── SubjectIntents.swift      — Look Up, Explain, Say, and Open (from Spotlight)
│   │   ├── WaniKaniShortcuts.swift   — Siri phrases
│   │   ├── OnscreenSubject.swift     — tells Siri which item is on screen
│   │   └── AppRouter.swift           — hands intent navigation to the dashboard
│   ├── Shared/                       — files compiled into BOTH app and widget targets
│   │   ├── WidgetWord.swift          — Codable word struct
│   │   └── WidgetSharedStore.swift   — App Group container read/write
│   ├── Storage/
│   │   ├── SubjectStore.swift        — SwiftData context for WaniKani subjects
│   │   ├── KanaSRSStore.swift        — SwiftData context for kana SRS entries
│   │   └── BurnedSRSStore.swift      — local schedule over burned items, selection and results
│   ├── Views/
│   │   ├── AuthView.swift            — API key entry and validation, first launch and changes
│   │   ├── HomeView.swift            — dashboard: goal ring, tiles, level progress
│   │   ├── ReviewCardView.swift      — shared quiz card used by both review modes
│   │   ├── ReviewSessionView.swift   — WaniKani review session
│   │   ├── LessonSessionView.swift   — lesson card UI
│   │   ├── KanjiHintSheet.swift      — single-item popup card: easy-mode hints, gold kanji, Spotlight
│   │   ├── PracticeReviewSetupView.swift   — category picker for kanji and vocab practice
│   │   ├── PracticeReviewSessionView.swift — kanji and vocab practice session
│   │   ├── BurnedStatsView.swift     — burned record: stages, Needs Work, Strongest
│   │   ├── NamePracticeSetupView.swift   — name practice mode picker
│   │   ├── NamePracticeSessionView.swift — name quiz and reveal
│   │   ├── KanaReviewView.swift      — kana practice UI
│   │   ├── KanjiProgressView.swift   — full kanji grid by level
│   │   ├── LevelDetailSheet.swift    — level breakdown sheet
│   │   ├── DailySentenceCard.swift   — AI sentence card on home screen
│   │   ├── InlineExampleCard.swift   — AI sentence card in lessons and reviews
│   │   ├── SentenceKanjiStrip.swift  — "Kanji in sentence" strip, unknown kanji in gold
│   │   ├── SettingsView.swift        — Easy Mode, AI model, API key, sync, sign out
│   │   ├── AIModelSetupView.swift    — backend switching, Qwen download, Claude key
│   │   ├── OfflineBanner.swift       — dismissable network warning banner
│   │   ├── PromptTestView.swift      — debug-only grammar prompt test harness
│   │   └── SelectableLabel.swift     — UITextView wrapper for selectable Japanese text, tappable kanji
│   ├── Prompts/                      — 135 grammar prompt .txt files (N5–N1)
│   ├── sentences.json                — static example sentences
│   ├── wanikani_vocab_sentences.json — pre-generated vocabulary sentences
│   ├── japanese_names.json           — surnames and given names with readings
│   └── subjects_bundle.json          — ~9,000 bundled subjects for offline seed
└── WaniWidget/
    ├── WaniWidgetBundle.swift        — widget extension entry point
    └── LockScreenWordWidget.swift    — Lock Screen vocabulary widget
```

---

## Evolution

The app started as a simple tool for one problem: getting through review backlogs without the friction of typing.

**Core review loop.** The first version pulled your available assignments from WaniKani and showed multiple choice cards for meaning and reading. It worked but was basic. Everything was fetched live on each session start and cards were shown one after another with no mixing.

**Subjects stored on device.** Fetching everything from the API on every launch was slow and hit rate limits fast. All ~9,000 WaniKani subjects were bundled into the app so they load instantly on first launch. After that the app only pulls down what has changed since the last sync.

**Mixed review queue.** The card order was reworked so meaning and reading cards for the same item are spread apart in the queue rather than shown back to back. This feels much closer to how WaniKani actually runs reviews.

**Example sentences.** Vocabulary items gained example sentences to give words more context. These were initially pre-generated and bundled into the app, then expanded with on-device AI generation using Qwen2.5 so any vocabulary word could get a sentence, not just the ones covered by the bundle. Apple Foundation Models was added as an alternative for iOS 26+.

**Lesson mode.** A lesson view was built so you can step through new items before they hit your review queue, the same way WaniKani's lesson system works. Each item is started on WaniKani as you advance through it.

**Kana practice.** Hiragana and katakana practice was added as a standalone mode with its own progress tracking, separate from WaniKani. Characters you struggle with come up more often until you've got them down.

**Kanji progress and level detail.** A kanji grid and level breakdown were added so you can see at a glance what you've passed and where you stand on your current level.

**Better sentences.** Neither local model produced reliably natural Japanese, so the approach changed: a larger model pre-generates sentences for vocabulary offline and they ship as a bundled database. On top of that, a Claude backend was added for anyone who wants to bring their own API key and generate on demand. Anything it generates is saved locally and folded back into the offline pool.

**Kanji Review.** A practice-only quiz mode that lets you drill kanji by SRS stage without touching your WaniKani data. Burned and enlightened items are the main reason it exists; WaniKani considers them finished and never shows them again.

**Easy Mode.** An option to run reviews on meanings alone, for when the backlog is large enough that halving the card count is the difference between doing them and not.

**Lock Screen widget.** A widget extension that surfaces vocabulary you've passed on the Lock Screen, rotating through the day, sharing data with the app through an App Group.

**Burned kanji schedule.** Kanji Review could reach burned kanji but had no memory of it, so the same handful kept coming up while others were never seen. A local SRS was added over every burned kanji, with a Burned Stats screen showing which ones have held up and which are fading, and the Lock Screen widget was pointed at burned vocabulary for the same reason.

**Answering before looking.** Multiple choice makes a card easy to recognize even when you couldn't have recalled it, which is fine for material you're actively learning and misleading for material you're not. Choices are now blurred behind a button on the cards where that matters: Master and Enlightened items in a real review, and everything in Kanji Review. Sessions were also reordered to lead with what's most worth doing, by level in reviews and by weakness in burned practice.

**Vocab Review.** Kanji Review turned out to be the mode I actually used, and the same gap exists on the vocabulary side: burned words are retired just as permanently, and a word you can't read is a word you've lost regardless of whether its kanji are solid. Vocab Review is the same screen over vocabulary, with its own burned schedule and its own Burned Stats, kept separate from the kanji one so neither borrows the other's record. Rather than copy the feature, the schedule, the setup screen and the session screen were made to take a subject kind, so both modes now run the same code.

**Hearing the reading.** Easy Mode shows a vocabulary word's reading, and a speaker button now reads it aloud on-device, so a word you're reviewing by meaning alone still has a sound attached to it.

**Sentences you can read.** Example sentences were only checked for the target word, so they'd happily lean on kanji a learner hadn't met yet. Now every source prefers sentences built from kanji you have at Master, the ones it can't avoid are marked in gold and open their card with a tap, and the Apple model can look up your known vocabulary while it writes. Retries were capped at the same time, and a bundled sentence replaces the error when generation doesn't work out.

**Siri and Shortcuts.** The app's main actions became App Intents: checking and starting reviews, lessons and burned practice from Siri or the Action button, looking up, explaining and hearing a word, and a Spotlight index of everything you've unlocked. On iOS 27, Siri can also refer to whichever item is on screen.

**Polish.** Over time the API key was moved to secure storage, a daily goal ring was added to the home screen, and offline warnings were added for when you lose connection mid-session.

---

## Setup

1. Open `WaniKaniHelper/WaniKaniHelper.xcodeproj` in Xcode 27+. The code references iOS 27 APIs behind availability checks, so it needs the iOS 27 SDK to build, but the app itself still runs on iOS 26.4+
2. Build and run the **WaniKaniHelper** scheme on a device or simulator (iOS 26.4+). The widget extension is embedded in the app, so it installs alongside it. Don't run the `WaniWidgetExtension` scheme directly.
3. Enter your WaniKani API key, which you can find at [wanikani.com/settings/access_tokens](https://www.wanikani.com/settings/access_tokens)
4. Subjects are seeded from the bundled database on first launch, then kept current by the daily background sync described above. No action needed

Example sentences work out of the box from the bundled database. To generate new ones, open **Settings → AI Model** and either paste an [Anthropic API key](https://console.anthropic.com/settings/keys) for Claude, download Qwen (~2 GB), or select Apple On-Device AI on iOS 26+.

Debug builds add **Settings → Developer → Prompt Test**, which runs the 135 grammar prompts against a chosen model and reports how often the target word appears, how many sentences use only known kanji, and whether the model called the known-words tool. It exists to re-check the prompts when Apple ships a new model, and the results can be shared as a text report.

To add the Lock Screen widget: long-press the Lock Screen → **Customize** → tap a widget slot → find **Fuyu** → **Vocab Word**. Open the app at least once first so it has words to show.

### Forking

Change the signing team and bundle identifiers to your own in Signing & Capabilities, for every target. The widget's identifier has to stay a child of the app's, e.g. `com.you.WaniKaniHelper` and `com.you.WaniKaniHelper.WaniWidget`.

Then enable **App Groups** on both the app and widget targets and add `group.<your app bundle id>`, matching the app identifier exactly. That naming is what lets the widget find the container without any code change.

There's also an **Apple Cloud** backend in the code, using Apple's Private Cloud Compute model on iOS 27, which is switched off. It needs the managed `com.apple.developer.private-cloud-compute` entitlement, which Apple grants on [request](https://developer.apple.com/contact/request/private-cloud-compute/). Without it the framework crashes rather than throwing an error, so the backend stays hidden unless `AppleCloud.isEntitled` in `AppleFoundationBackend.swift` is set to `true`. Only flip it after adding the entitlement.

---

## Credits

Name readings and per-kanji breakdowns are derived from [JMnedict](https://www.edrdg.org/enamdict/enamdict_doc.html) and [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project), both from the [Electronic Dictionary Research and Development Group](https://www.edrdg.org/) and used under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Surname frequency ordering comes from published census-based rankings.

WaniKani subject content is fetched from the [WaniKani API](https://docs.api.wanikani.com/) using your own token. WaniKani is a trademark of Tofugu LLC; this app is not affiliated with or endorsed by them.
