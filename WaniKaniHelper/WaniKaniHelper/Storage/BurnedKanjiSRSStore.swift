// SwiftData-backed local SRS schedule over the user's burned kanji.
//
// Burned items are retired on WaniKani — they never come up for review again — so without something
// like this, a burned kanji is only ever seen again by luck. This store learns which kanji are
// burned from the assignments Kanji Review already fetches, orders practice so newly burned and
// overdue kanji come first, and pushes each one further out as it keeps being answered correctly.
//
// Nothing here touches WaniKani: the schedule is this app's, and answering wrong costs the user
// nothing on their real SRS.
import SwiftData
import Foundation

@Observable
@MainActor
final class BurnedKanjiSRSStore {
    private let context: ModelContext

    /// Days until the next practice, indexed by `stage`. Stage 0 is "never practiced here yet".
    /// The gaps are long because this material is already mastered — the point is to catch a fade,
    /// not to drill.
    static let intervalDays = [0, 1, 3, 7, 14, 30, 90, 180]

    private static var maxStage: Int { intervalDays.count - 1 }

    init(context: ModelContext) {
        self.context = context
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("BurnedKanjiSRSStore save failed: \(error)")
        }
    }

    private func allEntries() -> [BurnedKanjiSRSEntry] {
        (try? context.fetch(FetchDescriptor<BurnedKanjiSRSEntry>())) ?? []
    }

    // MARK: - Sync

    /// Reconciles the tracked set against WaniKani. Pass the full kanji assignment list — the same
    /// one `KanjiReviewService.loadCategories()` already fetches, so this costs no extra requests.
    ///
    /// Newly burned kanji are inserted at stage 0 (due immediately, so they surface in the very next
    /// session). Kanji that are no longer burned are dropped: WaniKani lets you resurrect a burned
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
            context.insert(BurnedKanjiSRSEntry(subjectId: subjectId, burnedAt: burnedAt))
            changed = true
        }

        if changed { save() }
    }

    // MARK: - Counts

    var trackedCount: Int {
        (try? context.fetchCount(FetchDescriptor<BurnedKanjiSRSEntry>())) ?? 0
    }

    /// Burned kanji that have never come up in local practice.
    var newCount: Int {
        let descriptor = FetchDescriptor<BurnedKanjiSRSEntry>(
            predicate: #Predicate { $0.firstPracticedAt == nil }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Practiced burned kanji whose next review has come around.
    var dueCount: Int {
        let now = Date()
        let descriptor = FetchDescriptor<BurnedKanjiSRSEntry>(
            predicate: #Predicate { $0.firstPracticedAt != nil && $0.dueAt <= now }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Stats

    /// Human-readable name for a local stage, derived from the interval table so the two can't
    /// drift apart. Stage 0 is the "never practiced here" bucket.
    static func stageLabel(_ stage: Int) -> String {
        guard stage > 0, stage < intervalDays.count else { return "New" }
        return "\(intervalDays[stage])d"
    }

    /// Every tracked kanji as a value snapshot, for the stats screen to sort and slice without
    /// holding onto SwiftData models.
    func stats() -> [BurnedKanjiStat] {
        allEntries().map(Self.stat)
    }

    private static func stat(_ entry: BurnedKanjiSRSEntry) -> BurnedKanjiStat {
        BurnedKanjiStat(
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

    /// How many tracked kanji sit at each local stage, indexed by stage. Always
    /// `intervalDays.count` long, so the stats chart can render empty stages too.
    func stageCounts() -> [Int] {
        var counts = Array(repeating: 0, count: Self.intervalDays.count)
        for entry in allEntries() where counts.indices.contains(entry.stage) {
            counts[entry.stage] += 1
        }
        return counts
    }

    // MARK: - Selection

    /// Burned kanji to practice next, best-first:
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

        func weakestFirst(_ group: [BurnedKanjiSRSEntry]) -> [BurnedKanjiSRSEntry] {
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
        advance(entry, to: min(entry.stage + 1, Self.maxStage))
    }

    func recordIncorrect(subjectId: Int) {
        guard let entry = entry(for: subjectId) else { return }
        entry.consecutiveCorrect = 0
        entry.totalIncorrect += 1
        // Same drop-2 penalty the kana SRS uses, floored at stage 1 so a miss always comes back
        // tomorrow rather than landing in the "never practiced" bucket again.
        advance(entry, to: max(1, entry.stage - 2))
    }

    private func advance(_ entry: BurnedKanjiSRSEntry, to stage: Int) {
        let now = Date()
        entry.stage = stage
        if entry.firstPracticedAt == nil { entry.firstPracticedAt = now }
        entry.lastPracticedAt = now
        let days = Self.intervalDays[stage]
        entry.dueAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        save()
    }

    private func entry(for subjectId: Int) -> BurnedKanjiSRSEntry? {
        let id = subjectId
        var descriptor = FetchDescriptor<BurnedKanjiSRSEntry>(
            predicate: #Predicate { $0.subjectId == id }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
