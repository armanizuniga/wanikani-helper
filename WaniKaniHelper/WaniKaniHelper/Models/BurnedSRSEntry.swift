// The local SRS schedule's storage layer: one protocol describing a tracked burned subject, and the
// two SwiftData models that implement it (kanji and vocabulary).
//
// WaniKani never reviews a burned item again, so this is the only thing keeping burned material in
// rotation: each entry records when the item was burned, how well it's held up in local practice,
// and when it should next come around. Purely local — nothing here is ever sent to WaniKani.
//
// Kanji and vocabulary get separate models rather than one table with a type column: SwiftData
// models can't be generic, and keeping them apart means each schedule can be counted, fetched and
// (if ever needed) tuned on its own. `BurnedSRSStore` supplies the shared behaviour.
import SwiftData
import Foundation

/// The shape `BurnedSRSStore` needs from a tracked entry. The predicate factories are protocol
/// requirements because `#Predicate` has to be written against a concrete model type — SwiftData
/// can't translate one built over a generic parameter into a store query.
protocol BurnedSRSEntry: PersistentModel {
    init(subjectId: Int, burnedAt: Date?)

    var subjectId: Int { get set }
    var burnedAt: Date? { get set }
    var stage: Int { get set }
    var dueAt: Date { get set }
    var firstPracticedAt: Date? { get set }
    var lastPracticedAt: Date? { get set }
    var consecutiveCorrect: Int { get set }
    var totalCorrect: Int { get set }
    var totalIncorrect: Int { get set }

    static func subjectPredicate(id: Int) -> Predicate<Self>
    static var unpracticedPredicate: Predicate<Self> { get }
    static func duePredicate(now: Date) -> Predicate<Self>
}

@Model
final class BurnedKanjiSRSEntry: BurnedSRSEntry {
    @Attribute(.unique) var subjectId: Int
    var burnedAt: Date?           // when WaniKani burned it
    var stage: Int                // 0–7, local only; indexes BurnedSRS.intervalDays
    var dueAt: Date
    var firstPracticedAt: Date?   // nil == never practiced here == a "new" burn
    var lastPracticedAt: Date?
    var consecutiveCorrect: Int
    var totalCorrect: Int
    var totalIncorrect: Int

    init(subjectId: Int, burnedAt: Date?) {
        self.subjectId = subjectId
        self.burnedAt = burnedAt
        self.stage = 0
        // Immediately eligible: a freshly discovered burn should be practiceable right away.
        self.dueAt = .distantPast
        self.firstPracticedAt = nil
        self.lastPracticedAt = nil
        self.consecutiveCorrect = 0
        self.totalCorrect = 0
        self.totalIncorrect = 0
    }

    static func subjectPredicate(id: Int) -> Predicate<BurnedKanjiSRSEntry> {
        #Predicate { $0.subjectId == id }
    }

    static var unpracticedPredicate: Predicate<BurnedKanjiSRSEntry> {
        #Predicate { $0.firstPracticedAt == nil }
    }

    static func duePredicate(now: Date) -> Predicate<BurnedKanjiSRSEntry> {
        #Predicate { $0.firstPracticedAt != nil && $0.dueAt <= now }
    }
}

@Model
final class BurnedVocabSRSEntry: BurnedSRSEntry {
    @Attribute(.unique) var subjectId: Int
    var burnedAt: Date?
    var stage: Int
    var dueAt: Date
    var firstPracticedAt: Date?
    var lastPracticedAt: Date?
    var consecutiveCorrect: Int
    var totalCorrect: Int
    var totalIncorrect: Int

    init(subjectId: Int, burnedAt: Date?) {
        self.subjectId = subjectId
        self.burnedAt = burnedAt
        self.stage = 0
        self.dueAt = .distantPast
        self.firstPracticedAt = nil
        self.lastPracticedAt = nil
        self.consecutiveCorrect = 0
        self.totalCorrect = 0
        self.totalIncorrect = 0
    }

    static func subjectPredicate(id: Int) -> Predicate<BurnedVocabSRSEntry> {
        #Predicate { $0.subjectId == id }
    }

    static var unpracticedPredicate: Predicate<BurnedVocabSRSEntry> {
        #Predicate { $0.firstPracticedAt == nil }
    }

    static func duePredicate(now: Date) -> Predicate<BurnedVocabSRSEntry> {
        #Predicate { $0.firstPracticedAt != nil && $0.dueAt <= now }
    }
}
