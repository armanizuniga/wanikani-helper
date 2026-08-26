// App-side glue between the SwiftData subject cache and the Lock Screen widget.
// Picks the user's learned (passed) vocabulary, writes a small pool into the shared
// App Group container, and asks WidgetKit to refresh the timeline.
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
    /// and whenever pass state changes. Falls back to early-level vocab so a brand-new user
    /// (no passes yet) still sees words instead of an empty widget.
    static func update(using store: SubjectStore) {
        var words = store.passedVocabularyWords()
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
