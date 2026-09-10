// SwiftData model tracking one burned kanji in the app's own SRS schedule.
// WaniKani never reviews a burned item again, so this is the only thing keeping burned kanji in
// rotation: it records when the item was burned, how well it's held up in local practice, and when
// it should next come around. Purely local — nothing here is ever sent to WaniKani.
import SwiftData
import Foundation

@Model
final class BurnedKanjiSRSEntry {
    @Attribute(.unique) var subjectId: Int
    var burnedAt: Date?           // when WaniKani burned it
    var stage: Int                // 0–7, local only; indexes BurnedKanjiSRSStore.intervalDays
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
}
