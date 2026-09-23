// Which subject type a local practice session covers. Kanji Review and Vocab Review are the same
// feature over different material, so the pieces they share — the burned-SRS store, the stats
// screen — take one of these instead of being written twice.
import Foundation

enum PracticeKind: String, Identifiable {
    case kanji
    case vocabulary

    var id: String { rawValue }

    /// Screen title for the practice feature itself.
    var reviewTitle: String {
        switch self {
        case .kanji:      return "Kanji Review"
        case .vocabulary: return "Vocab Review"
        }
    }

    /// Plural noun for counts and running copy — "15 kanji", "15 words".
    var pluralNoun: String {
        switch self {
        case .kanji:      return "kanji"
        case .vocabulary: return "words"
        }
    }

    /// Same noun with the subject type spelled out, for headings and empty states.
    var formalPluralNoun: String {
        switch self {
        case .kanji:      return "kanji"
        case .vocabulary: return "vocabulary"
        }
    }

    /// SF Symbol for the empty state on the setup screen.
    var emptyStateSymbol: String {
        switch self {
        case .kanji:      return "character.book.closed"
        case .vocabulary: return "text.book.closed"
        }
    }
}
