// SwiftData model representing a single WaniKani subject (radical, kanji, or vocabulary).
// Persisted locally and seeded from subjects_bundle.json on first launch, then kept in sync
// via the WaniKani API. Tracks pass/burn state to reflect the user's real WaniKani progress.
import SwiftData
import Foundation

enum SubjectType: String, Codable {
    case radical
    case kanji
    case vocabulary
    case kanaVocabulary = "kana_vocabulary"

    var isVocab: Bool { self == .vocabulary || self == .kanaVocabulary }
    var hasReading: Bool { self != .radical && self != .kanaVocabulary }
}

@Model
final class CachedSubject {
    @Attribute(.unique) var id: Int
    var type: String
    var characters: String?
    var slug: String?
    var level: Int
    var meanings: [String]
    var readings: [String]
    var meaningMnemonic: String?
    var characterImageURL: String?
    var hiddenAt: Date?
    var updatedAt: Date
    var componentSubjectIds: [Int] = []

    var isPassed: Bool = false
    var isBurned: Bool = false
    var lastReviewedAt: Date?

    var subjectType: SubjectType { SubjectType(rawValue: type) ?? .vocabulary }

    init(
        id: Int,
        type: String,
        characters: String?,
        slug: String?,
        level: Int,
        meanings: [String],
        readings: [String],
        meaningMnemonic: String?,
        characterImageURL: String? = nil,
        hiddenAt: Date?,
        updatedAt: Date,
        componentSubjectIds: [Int] = []
    ) {
        self.id = id
        self.type = type
        self.characters = characters
        self.slug = slug
        self.level = level
        self.meanings = meanings
        self.readings = readings
        self.meaningMnemonic = meaningMnemonic
        self.characterImageURL = characterImageURL
        self.hiddenAt = hiddenAt
        self.updatedAt = updatedAt
        self.componentSubjectIds = componentSubjectIds
    }
}
