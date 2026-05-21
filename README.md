# WaniKani Helper

[WaniKani](https://www.wanikani.com) is a web-based Japanese kanji learning platform that uses spaced repetition (SRS) to teach radicals, kanji, and vocabulary.

The further you progress the easier it is for reviews to pile up, and missing a day might mean you come back to hundreds waiting. WaniKani is strict about what it accepts — specific romanizations, exact meanings, and particular phrasing for vocabulary — so a typo or a close but wrong answer counts as incorrect and every mistake feels like a setback. It gets time consuming and starts to feel impossible to catch up on.

WaniKani Helper is a free iOS app built to fix that. It swaps the type-in input for multiple choice so there are no typos and you can move through reviews much faster. The goal is just to make it feel manageable enough that you actually want to sit down and do them. It connects to WaniKani through their official API using your own API key, so your reviews and lessons always pull from your real account and results are submitted back as you go.

---

## Features

### Review session

Each item gets two cards, one for meaning and one for reading. They're mixed into the queue so you're not just answering meaning then reading back to back for every item. Each card gives you four choices. After answering you see the correct meaning and reading, any component radicals or kanji, example sentences for vocabulary, and the mnemonic. Results are submitted to WaniKani as you go.

### Lesson session

Steps through your pending lessons in the same order WaniKani uses: radicals first, then kanji, then vocabulary. Each item shows its meaning, reading, how it breaks down, and example sentences for vocabulary. Moving past an item starts it on WaniKani so it shows up in your reviews.

### Kana practice

A standalone hiragana and katakana practice mode with its own SRS, separate from WaniKani. Each character has a mastery level that goes up as you get it right and drops when you get it wrong. Characters you struggle with show up more often until you've got them down.

### AI example sentences

Vocabulary items can show an AI-generated Japanese sentence using the target word. Two on-device backends are supported:

- **Qwen2.5** — downloaded on-device, runs fully offline after download
- **Apple Foundation Models** — available on iOS 26+, no download required

Sentences are picked from one of 135 grammar prompts spanning N5 to N1, selected based on your WaniKani level.

> **Work in progress.** This feature is still being refined. Apple Foundation Models triggers safety guardrails on a large number of vocabulary words, blocking generation entirely. Qwen2.5 can produce sentences but they are often not grammatically correct or natural sounding Japanese. The current approach being explored is using a larger external model to pre-generate sentences and grammar explanations for every vocabulary word and load them into a bundled database the app pulls from. This would make the feature fully offline, consistent, and much higher quality.

### Kanji progress

A scrollable grid of every WaniKani kanji grouped by level. Passed kanji are shown in pink; unlearned ones are greyed out. Pass status is synced from WaniKani assignments at launch and updated locally after each review submission.

### Level detail

A breakdown of your current level showing radicals, kanji, and vocabulary grouped into passed, in-progress, and not-started, with each item showing how far along it is in the SRS.

### Offline support

All subjects are stored on your device so the app works even without a connection. On first launch they're loaded from a built-in database of ~9,000 WaniKani subjects. Your account data is refreshed in the background each time you open the app, and a banner lets you know if you lose connection mid-session.

> **Planned.** Full offline review and lesson support is something we want to add. The idea is to let you complete reviews and lessons normally while offline, save the results locally, and automatically sync everything back to WaniKani once your connection is restored. That way being without internet is never a reason to skip a session.

---

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| AI (on-device) | MLXLLM — Qwen2.5-3B-Instruct-4bit |
| AI (system) | Apple FoundationModels (iOS 26+) |
| API | WaniKani API v2 |
| Auth | Keychain via Security framework |

---

## Project structure

```
WaniKaniHelper/WaniKaniHelper/
├── WaniKaniHelperApp.swift       — app entry, auth routing, bootstrap
├── Models/
│   ├── Subject.swift             — CachedSubject SwiftData model
│   ├── ReviewItem.swift          — ReviewItem struct, QuestionType enum
│   └── KanaSRSEntry.swift        — KanaSRSEntry SwiftData model
├── Services/
│   ├── WaniKaniAPI.swift         — API client, all endpoints, response types
│   ├── ReviewService.swift       — review session state and submission logic
│   ├── LessonService.swift       — lesson session state
│   ├── KanaReviewService.swift   — kana session state and grading
│   ├── KanaData.swift            — static hiragana/katakana tables
│   ├── SentenceStore.swift       — loads sentences.json for static examples
│   ├── SentenceGeneratorService.swift  — AI sentence generation for home card
│   ├── ExampleGeneratorService.swift   — AI sentence generation for review/lesson
│   ├── PromptLibrary.swift       — selects grammar prompts by user level
│   ├── SubjectBundler.swift      — BundledSubject Codable struct for bundle import
│   ├── RadicalImageCache.swift   — disk cache and SVG renderer for radical images
│   ├── KeychainService.swift     — API key storage
│   ├── DailyGoal.swift           — daily review count, resets at midnight
│   └── AI/
│       ├── AIBackend.swift       — AIGeneratedContent struct, AIBackend protocol
│       ├── AIModelManager.swift  — backend selection and download lifecycle
│       ├── MLCQwenBackend.swift  — Qwen2.5 via MLXLLM
│       └── AppleFoundationBackend.swift — FoundationModels backend (iOS 26+)
├── Storage/
│   ├── SubjectStore.swift        — SwiftData context for WaniKani subjects
│   └── KanaSRSStore.swift        — SwiftData context for kana SRS entries
├── Views/
│   ├── AuthView.swift            — API key entry and validation
│   ├── HomeView.swift            — dashboard: goal ring, tiles, level progress, AI card
│   ├── ReviewSessionView.swift   — review UI with multiple-choice grid
│   ├── LessonSessionView.swift   — lesson card UI
│   ├── KanaReviewView.swift      — kana practice UI
│   ├── KanjiProgressView.swift   — full kanji grid by level
│   ├── LevelDetailSheet.swift    — level breakdown sheet
│   ├── DailySentenceCard.swift   — AI sentence card on home screen
│   ├── InlineExampleCard.swift   — AI sentence card in lessons and reviews
│   ├── AIModelSetupView.swift    — Qwen download/delete, backend switching
│   ├── OfflineBanner.swift       — dismissable network warning banner
│   └── SelectableLabel.swift     — UITextView wrapper for selectable Japanese text
├── Prompts/                      — 135 grammar prompt .txt files (N5–N1)
├── sentences.json                — static example sentences
└── subjects_bundle.json          — ~9,000 bundled subjects for offline seed
```

---

## Evolution

The app started as a simple tool for one problem: getting through review backlogs without the friction of typing.

**Core review loop** — the first version pulled your available assignments from WaniKani and showed multiple choice cards for meaning and reading. It worked but was basic. Everything was fetched live on each session start and cards were shown one after another with no mixing.

**Subjects stored on device** — fetching everything from the API on every launch was slow and hit rate limits fast. All ~9,000 WaniKani subjects were bundled into the app so they load instantly on first launch. After that the app only pulls down what has changed since the last sync.

**Mixed review queue** — the card order was reworked so meaning and reading cards for the same item are spread apart in the queue rather than shown back to back. This feels much closer to how WaniKani actually runs reviews.

**Example sentences** — vocabulary items gained example sentences to give words more context. These were initially pre-generated and bundled into the app, then expanded with on-device AI generation using Qwen2.5 so any vocabulary word could get a sentence, not just the ones covered by the bundle. Apple Foundation Models was added as an alternative for iOS 26+.

**Lesson mode** — a lesson view was built so you can step through new items before they hit your review queue, the same way WaniKani's lesson system works. Each item is started on WaniKani as you advance through it.

**Kana practice** — hiragana and katakana practice was added as a standalone mode with its own progress tracking, separate from WaniKani. Characters you struggle with come up more often until you've got them down.

**Kanji progress and level detail** — a kanji grid and level breakdown were added so you can see at a glance what you've passed and where you stand on your current level.

**Polish** — over time the API key was moved to secure storage, a daily goal ring was added to the home screen, offline warnings were added for when you lose connection mid-session, and radical images were cached so they don't need to be fetched every time.

---

## Setup

1. Open `WaniKaniHelper/WaniKaniHelper.xcodeproj` in Xcode 26+
2. Build and run on a device or simulator (iOS 16+)
3. Enter your WaniKani API key — find it at [wanikani.com/settings/access_tokens](https://www.wanikani.com/settings/access_tokens)
4. Subjects are seeded from the bundle on first launch; use **Sync Subjects** in the Tools section to pull in updates

For AI sentence generation, use **AI Model Setup** in Tools to download Qwen (~2 GB) or rely on Apple Foundation Models if running iOS 26+.
