// App-side glue between the SwiftData subject cache and the Lock Screen widget.
// Picks the user's burned vocabulary (falling back to merely learned words), writes a small pool
// into the shared App Group container, and asks WidgetKit to refresh the timeline.
import Foundation
import WidgetKit

extension WidgetWord {
    /// Builds a widget word from a cached subject, or returns nil if it can't be shown
    /// (missing characters or meaning). Radicals/kanji are filtered out by the caller.
    init?(subject: CachedSubject) {
        guard let chars = subject.characters, !chars.isEmpty else { return nil }
        guard let meaning = subject.meanings.first else { return nil }

        let reading: String
        if subject.subjectType == .kanaVocabulary {
            reading = chars   // kana vocab: the characters already are the reading
        } else {
            reading = subject.readings.first ?? ""
        }
        self.init(characters: chars, reading: reading, meaning: meaning, level: subject.level)
    }
}

@MainActor
enum WidgetWordSync {
    /// Refreshes the shared word pool and reloads the widget. Cheap; safe to call on launch
    /// and whenever pass/burn state changes.
    ///
    /// Burned vocabulary comes first: those words are gone from WaniKani reviews forever, so the
    /// Lock Screen is the only place they'll be seen again. Passed vocabulary and then early-level
    /// vocabulary back it up, so a user with no burns yet — or a fresh install — still sees words
    /// instead of an empty widget.
    static func update(using store: SubjectStore) {
        var words = store.burnedVocabularyWords()
        if words.isEmpty {
            words = store.passedVocabularyWords()
        }
        if words.isEmpty {
            words = store.fallbackVocabularyWords()
        }
        WidgetShared.save(words)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Empties the shared pool on sign-out so the previous account's vocabulary doesn't linger
    /// on the Lock Screen. The widget falls back to its "open the app" state.
    static func clear() {
        WidgetShared.save([])
        WidgetCenter.shared.reloadAllTimelines()
    }
}
