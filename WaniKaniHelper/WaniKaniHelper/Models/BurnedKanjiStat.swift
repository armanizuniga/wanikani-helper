// A read-only snapshot of one burned kanji's local practice record, used by the Burned Stats
// screen. A value type rather than the SwiftData model so the view can sort, partition and rank
// freely — and so the ranking rule below is testable on its own.
import Foundation

struct BurnedKanjiStat: Identifiable, Equatable {
    let subjectId: Int
    let stage: Int                  // 0–7, indexes BurnedKanjiSRSStore.intervalDays
    let dueAt: Date
    let burnedAt: Date?
    let lastPracticedAt: Date?
    let totalCorrect: Int
    let totalIncorrect: Int
    let consecutiveCorrect: Int

    var id: Int { subjectId }

    var attempts: Int { totalCorrect + totalIncorrect }

    /// False for a kanji WaniKani has burned that this app has never quizzed — it has no record
    /// yet, so it belongs in neither ranking.
    var isPracticed: Bool { attempts > 0 }

    /// Correct answers in a row that clear a past miss.
    ///
    /// Lifetime misses alone can't decide the two rankings: `totalIncorrect` only ever grows, so a
    /// single bad day would hold a kanji in "Needs Work" forever no matter how well it was known
    /// afterwards. A streak is the way back — long enough that it has to survive several widening
    /// intervals, since a miss drops the entry two stages and it has to climb out again.
    static let redemptionStreak = 4

    /// True when the kanji currently reads as solid: never missed here, or missed and since
    /// answered right `redemptionStreak` times running.
    var isStrong: Bool {
        guard isPracticed else { return false }
        return totalIncorrect == 0 || consecutiveCorrect >= Self.redemptionStreak
    }

    /// True while a miss is on record and the streak hasn't cleared it yet.
    var needsWork: Bool { isPracticed && !isStrong }

    /// True for a kanji that was missed here and has since earned its way back.
    var isRecovered: Bool { isStrong && totalIncorrect > 0 }

    /// Correct answers still needed to clear a past miss. 0 once nothing is left to prove.
    var answersToRecover: Int {
        guard needsWork else { return 0 }
        return max(0, Self.redemptionStreak - consecutiveCorrect)
    }

    /// True accuracy, for display. Nil until the kanji has actually been practiced here.
    var accuracy: Double? {
        guard attempts > 0 else { return nil }
        return Double(totalCorrect) / Double(attempts)
    }

    /// Accuracy for *ranking*, smoothed toward 50% by one imaginary right and one imaginary wrong
    /// answer.
    ///
    /// Raw accuracy can't order these sensibly: 1/1 and 20/20 both score 1.0, and 0/1 and 0/5 both
    /// score 0, so the lists would be dominated by whichever kanji happened to be answered once.
    /// Smoothing breaks those ties by weight of evidence in both directions at once — the kanji
    /// missed five times sinks below the one missed once in "Needs Work", and a long clean record
    /// outranks a single lucky answer in "Strongest". Which list a kanji lands in is decided by
    /// `isStrong`; this only orders it once it's there.
    var rankScore: Double {
        Double(totalCorrect + 1) / Double(attempts + 2)
    }
}
