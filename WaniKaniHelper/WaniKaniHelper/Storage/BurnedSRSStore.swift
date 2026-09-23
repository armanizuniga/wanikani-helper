// SwiftData-backed local SRS schedule over the user's burned subjects.
//
// Burned items are retired on WaniKani — they never come up for review again — so without something
// like this, a burned kanji or word is only ever seen again by luck. This store learns what is
// burned from the assignments the practice feature already fetches, orders practice so newly burned
// and overdue items come first, and pushes each one further out as it keeps being answered
// correctly.
//
// Nothing here touches WaniKani: the schedule is this app's, and answering wrong costs the user
// nothing on their real SRS.
//
// The class is generic over the entry model so kanji and vocabulary run identical logic against
// their own tables. `BurnedKanjiSRSStore` and `BurnedVocabSRSStore` below are the two concrete
// spellings.
import SwiftData
import Foundation

/// Schedule constants shared by every burned store, kept off the generic class so views can read
/// them without naming an entry type.
enum BurnedSRS {
    /// Days until the next practice, indexed by `stage`. Stage 0 is "never practiced here yet".
    /// The gaps are long because this material is already mastered — the point is to catch a fade,
    /// not to drill.
    static let intervalDays = [0, 1, 3, 7, 14, 30, 90, 180]

    static var maxStage: Int { intervalDays.count - 1 }

    /// Human-readable name for a local stage, derived from the interval table so the two can't
    /// drift apart. Stage 0 is the "never practiced here" bucket.
    static func stageLabel(_ stage: Int) -> String {
        guard stage > 0, stage < intervalDays.count else { return "New" }
        return "\(intervalDays[stage])d"
    }
}

/// Everything the practice feature and the Burned Stats screen ask of a schedule. Both are written
/// against this rather than the generic class, so one setup screen, one session screen and one
/// service cover kanji and vocabulary alike.
@MainActor
protocol BurnedSRSStoring: AnyObject {
    var trackedCount: Int { get }
    var dueCount: Int { get }
    func stats() -> [BurnedStat]
    func stageCounts() -> [Int]
    func sync(assignments: [WKResource<WKAssignmentData>])
    func prioritizedSubjectIds(limit: Int) -> [Int]
    func recordCorrect(subjectId: Int)
    func recordIncorrect(subjectId: Int)
}

@Observable
@MainActor
final class BurnedSRSStore<Entry: BurnedSRSEntry>: BurnedSRSStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("BurnedSRSStore save failed: \(error)")
        }
    }

    private func allEntries() -> [Entry] {
        (try? context.fetch(FetchDescriptor<Entry>())) ?? []
    }

    // MARK: - Sync

    /// Reconciles the tracked set against WaniKani. Pass the full assignment list for this subject
    /// type — the same one the practice service already fetches, so this costs no extra requests.
    ///
    /// Newly burned items are inserted at stage 0 (due immediately, so they surface in the very next
    /// session). Items that are no longer burned are dropped: WaniKani lets you resurrect a burned
    /// item, and once it's back in the real SRS it doesn't belong in this queue.
    func sync(assignments: [WKResource<WKAssignmentData>]) {
        var burnedAtBySubject: [Int: Date?] = [:]
        for resource in assignments where !resource.data.hidden {
            guard resource.data.srsStage >= SRSStage.burned else { continue }
            burnedAtBySubject[resource.data.subjectId] = resource.data.burnedAt
        }

        var changed = false
        var tracked = Set<Int>()

        for entry in allEntries() {
            if let burnedAt = burnedAtBySubject[entry.subjectId] {
                tracked.insert(entry.subjectId)
                // Backfill a burn date that was missing when the entry was first created.
                if entry.burnedAt == nil, burnedAt != nil {
                    entry.burnedAt = burnedAt
                    changed = true
                }
            } else {
                context.delete(entry)   // resurrected, hidden, or no longer ours
                changed = true
            }
        }

        for (subjectId, burnedAt) in burnedAtBySubject where !tracked.contains(subjectId) {
            context.insert(Entry(subjectId: subjectId, burnedAt: burnedAt))
            changed = true
        }

        if changed { save() }
    }

    // MARK: - Counts

    var trackedCount: Int {
        (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
    }

    /// Burned subjects that have never come up in local practice.
    var newCount: Int {
        let descriptor = FetchDescriptor<Entry>(predicate: Entry.unpracticedPredicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Practiced burned subjects whose next review has come around.
    var dueCount: Int {
        let descriptor = FetchDescriptor<Entry>(predicate: Entry.duePredicate(now: Date()))
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Stats

    /// Every tracked subject as a value snapshot, for the stats screen to sort and slice without
    /// holding onto SwiftData models.
    func stats() -> [BurnedStat] {
        allEntries().map(Self.stat)
    }

    private static func stat(_ entry: Entry) -> BurnedStat {
        BurnedStat(
            subjectId: entry.subjectId,
            stage: entry.stage,
            dueAt: entry.dueAt,
            burnedAt: entry.burnedAt,
            lastPracticedAt: entry.lastPracticedAt,
            totalCorrect: entry.totalCorrect,
            totalIncorrect: entry.totalIncorrect,
            consecutiveCorrect: entry.consecutiveCorrect
        )
    }

    /// How many tracked subjects sit at each local stage, indexed by stage. Always
    /// `BurnedSRS.intervalDays.count` long, so the stats chart can render empty stages too.
    func stageCounts() -> [Int] {
        var counts = Array(repeating: 0, count: BurnedSRS.intervalDays.count)
        for entry in allEntries() where counts.indices.contains(entry.stage) {
            counts[entry.stage] += 1
        }
        return counts
    }

    // MARK: - Selection

    /// Burned subjects to practice next, best-first:
    ///   1. never practiced here, most recently burned first — so a new burn is always noticed;
    ///   2. due, weakest first;
    ///   3. not yet due, weakest first — filler, so a session is never short.
    ///
    /// Weakness decides the order inside each bucket, because due date alone kept surfacing
    /// whatever had simply waited longest, which is rarely what's actually fading. Due still
    /// outranks not-due, so the interval table isn't just ignored. "Weakest" is the same smoothed
    /// score the stats screen ranks by, so what the user sees at the top of Needs Work is what
    /// comes up first here.
    func prioritizedSubjectIds(limit: Int) -> [Int] {
        guard limit > 0 else { return [] }
        let now = Date()
        let entries = allEntries()

        let fresh = entries
            .filter { $0.firstPracticedAt == nil }
            .sorted { ($0.burnedAt ?? .distantPast) > ($1.burnedAt ?? .distantPast) }

        func weakestFirst(_ group: [Entry]) -> [Entry] {
            group.sorted {
                let left = Self.stat($0).rankScore, right = Self.stat($1).rankScore
                return left == right ? $0.dueAt < $1.dueAt : left < right
            }
        }

        let practiced = entries.filter { $0.firstPracticedAt != nil }
        let due = weakestFirst(practiced.filter { $0.dueAt <= now })
        let upcoming = weakestFirst(practiced.filter { $0.dueAt > now })

        return (fresh + due + upcoming).prefix(limit).map { $0.subjectId }
    }

    // MARK: - Results

    func recordCorrect(subjectId: Int) {
        guard let entry = entry(for: subjectId) else { return }
        entry.consecutiveCorrect += 1
        entry.totalCorrect += 1
        advance(entry, to: min(entry.stage + 1, BurnedSRS.maxStage))
    }

    func recordIncorrect(subjectId: Int) {
        guard let entry = entry(for: subjectId) else { return }
        entry.consecutiveCorrect = 0
        entry.totalIncorrect += 1
        // Same drop-2 penalty the kana SRS uses, floored at stage 1 so a miss always comes back
        // tomorrow rather than landing in the "never practiced" bucket again.
        advance(entry, to: max(1, entry.stage - 2))
    }

    private func advance(_ entry: Entry, to stage: Int) {
        let now = Date()
        entry.stage = stage
        if entry.firstPracticedAt == nil { entry.firstPracticedAt = now }
        entry.lastPracticedAt = now
        let days = BurnedSRS.intervalDays[stage]
        entry.dueAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        save()
    }

    private func entry(for subjectId: Int) -> Entry? {
        var descriptor = FetchDescriptor<Entry>(predicate: Entry.subjectPredicate(id: subjectId))
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

typealias BurnedKanjiSRSStore = BurnedSRSStore<BurnedKanjiSRSEntry>
typealias BurnedVocabSRSStore = BurnedSRSStore<BurnedVocabSRSEntry>
