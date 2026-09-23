// Siri phrases for the app's intents. Listing them here makes them available in Siri, Spotlight,
// the Shortcuts app and the Action button with no setup from the user. Every phrase must include
// the app name token.
import AppIntents

struct WaniKaniShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckReviewsIntent(),
            phrases: [
                "How many reviews do I have in \(.applicationName)",
                "Check my \(.applicationName) reviews",
                "Do I have \(.applicationName) reviews",
            ],
            shortTitle: "Check Reviews",
            systemImageName: "tray.full"
        )
        AppShortcut(
            intent: StartReviewsIntent(),
            phrases: [
                "Start my \(.applicationName) reviews",
                "Start reviews in \(.applicationName)",
                "Do my \(.applicationName) reviews",
            ],
            shortTitle: "Start Reviews",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StartLessonsIntent(),
            phrases: [
                "Start my \(.applicationName) lessons",
                "Start lessons in \(.applicationName)",
            ],
            shortTitle: "Start Lessons",
            systemImageName: "book.fill"
        )
        AppShortcut(
            intent: StartPracticeIntent(),
            phrases: [
                "Quiz me on \(\.$kind) in \(.applicationName)",
                "Practice \(\.$kind) in \(.applicationName)",
                "Start \(.applicationName) burned practice",
            ],
            shortTitle: "Burned Practice",
            systemImageName: "flame.fill"
        )
        // No word in the phrase: Siri asks "Which word?" and resolves the answer through
        // SubjectEntityQuery. Thousands of items are too many for parameterized phrases.
        AppShortcut(
            intent: LookUpSubjectIntent(),
            phrases: [
                "Look up a word in \(.applicationName)",
                "Look up a kanji in \(.applicationName)",
                "What does a word mean in \(.applicationName)",
            ],
            shortTitle: "Look Up Word",
            systemImageName: "character.book.closed"
        )
        // On iOS 27, "explain this word" / "say this" resolve the word from the screen
        // (OnscreenSubject.swift); these phrases cover asking from anywhere else.
        AppShortcut(
            intent: ExplainSubjectIntent(),
            phrases: [
                "Explain a word in \(.applicationName)",
                "Explain a kanji in \(.applicationName)",
            ],
            shortTitle: "Explain Word",
            systemImageName: "text.book.closed"
        )
        AppShortcut(
            intent: SaySubjectIntent(),
            phrases: [
                "Say a word in \(.applicationName)",
                "Pronounce a word in \(.applicationName)",
            ],
            shortTitle: "Say Word",
            systemImageName: "speaker.wave.2.fill"
        )
    }
}
