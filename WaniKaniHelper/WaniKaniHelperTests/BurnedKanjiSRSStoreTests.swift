// Tests for the local SRS schedule over burned kanji.
//
// Burned items are retired on WaniKani and never reviewed again, so this store is the only thing
// deciding whether a burned kanji is ever seen again. Two behaviors carry that weight and are what
// these tests pin down:
//
//   sync()                  — which kanji are in the queue at all (and that a resurrected kanji
//                             leaves it, since it's back in WaniKani's own SRS)
//   prioritizedSubjectIds() — the order, which is what makes a newly burned kanji impossible to
//                             miss and stops the same 25 from repeating session after session
import Testing
import Foundation
import SwiftData
@testable import WaniKaniHelper

@MainActor
struct BurnedKanjiSRSStoreTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BurnedKanjiSRSEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Builds assignment resources the way the API layer would, by decoding — WKResource is
    /// Decodable-only, and this keeps the test honest about the real JSON shape.
    private func assignments(_ specs: [(subjectId: Int, srsStage: Int, burnedAt: String?)])
        throws -> [WKResource<WKAssignmentData>]
    {
        let objects = specs.map { spec -> String in
            let burned = spec.burnedAt.map { "\"\($0)\"" } ?? "null"
            return """
            {
              "id": \(spec.subjectId),
              "object": "assignment",
              "url": "https://api.wanikani.com/v2/assignments/\(spec.subjectId)",
              "data_updated_at": "2026-01-01T00:00:00.000000Z",
              "data": {
                "subject_id": \(spec.subjectId),
                "subject_type": "kanji",
                "srs_stage": \(spec.srsStage),
                "level": 5,
                "hidden": false,
                "burned_at": \(burned)
              }
            }
            """
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try objects.map {
            try decoder.decode(WKResource<WKAssignmentData>.self, from: Data($0.utf8))
        }
    }

    private func insert(
        _ context: ModelContext,
        subjectId: Int,
        stage: Int,
        dueAt: Date,
        firstPracticedAt: Date?,
        totalCorrect: Int = 0,
        totalIncorrect: Int = 0
    ) {
        let entry = BurnedKanjiSRSEntry(subjectId: subjectId, burnedAt: nil)
        entry.stage = stage
        entry.dueAt = dueAt
        entry.firstPracticedAt = firstPracticedAt
        entry.totalCorrect = totalCorrect
        entry.totalIncorrect = totalIncorrect
        context.insert(entry)
    }

    // MARK: - sync

    // Only stage 9 belongs in the queue. Anything below it is still in WaniKani's own SRS and will
    // come back on its own, so tracking it here would just duplicate reviews the user already has.
    @Test func sync_tracksOnlyBurnedKanji() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
            (subjectId: 2, srsStage: 8, burnedAt: nil),   // enlightened, not burned
            (subjectId: 3, srsStage: 9, burnedAt: "2026-08-02T00:00:00.000000Z"),
        ]))

        #expect(store.trackedCount == 2)
        #expect(Set(store.prioritizedSubjectIds(limit: 10)) == [1, 3])
    }

    // A brand-new burn is immediately eligible — it's "new", never practiced, and due at once.
    @Test func sync_newBurnIsImmediatelyDue() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))

        #expect(store.newCount == 1)
        #expect(store.prioritizedSubjectIds(limit: 10) == [1])
    }

    // WaniKani lets you resurrect a burned item. Once it's back in the real SRS it must leave this
    // queue, or the user would be practicing it in two places at once.
    @Test func sync_dropsResurrectedKanji() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
            (subjectId: 2, srsStage: 9, burnedAt: "2026-08-02T00:00:00.000000Z"),
        ]))
        #expect(store.trackedCount == 2)

        // Kanji 1 has been resurrected back to Apprentice.
        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 1, burnedAt: nil),
            (subjectId: 2, srsStage: 9, burnedAt: "2026-08-02T00:00:00.000000Z"),
        ]))

        #expect(store.trackedCount == 1)
        #expect(store.prioritizedSubjectIds(limit: 10) == [2])
    }

    // Syncing twice must not duplicate entries or reset progress on kanji already tracked.
    @Test func sync_isIdempotent() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let specs = [(subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z")]

        try store.sync(assignments: assignments(specs))
        store.recordCorrect(subjectId: 1)
        try store.sync(assignments: assignments(specs))

        #expect(store.trackedCount == 1)
        #expect(store.newCount == 0)   // still counted as practiced
    }

    // MARK: - Ordering

    // The whole point of the feature: a kanji burned yesterday and never practiced here beats
    // everything else, and the newest burn beats an older one.
    @Test func prioritized_newBurnsFirstNewestFirst() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let now = Date()

        // Two never-practiced burns, plus one long-overdue practiced kanji.
        try store.sync(assignments: assignments([
            (subjectId: 10, srsStage: 9, burnedAt: "2026-01-01T00:00:00.000000Z"),  // older burn
            (subjectId: 20, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),  // newer burn
        ]))
        insert(context, subjectId: 30, stage: 3,
               dueAt: now.addingTimeInterval(-60 * 60 * 24 * 30), firstPracticedAt: now)

        #expect(store.prioritizedSubjectIds(limit: 10) == [20, 10, 30])
    }

    // Among practiced kanji, due comes before not-yet-due, so a session is never short but never
    // wastes slots either. With no practice record to separate them, the longest-overdue leads.
    @Test func prioritized_dueBeforeUpcomingOldestFirst() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let now = Date()
        let day: TimeInterval = 60 * 60 * 24

        insert(context, subjectId: 1, stage: 2, dueAt: now.addingTimeInterval(day * 5),
               firstPracticedAt: now)              // not due for 5 days
        insert(context, subjectId: 2, stage: 2, dueAt: now.addingTimeInterval(-day * 2),
               firstPracticedAt: now)              // 2 days overdue
        insert(context, subjectId: 3, stage: 2, dueAt: now.addingTimeInterval(-day * 9),
               firstPracticedAt: now)              // 9 days overdue

        #expect(store.prioritizedSubjectIds(limit: 10) == [3, 2, 1])
        #expect(store.dueCount == 2)
    }

    @Test func prioritized_respectsLimit() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let specs = (1...40).map {
            (subjectId: $0, srsStage: 9, burnedAt: String?("2026-08-01T00:00:00.000000Z"))
        }
        try store.sync(assignments: assignments(specs))

        #expect(store.prioritizedSubjectIds(limit: 25).count == 25)
        #expect(store.prioritizedSubjectIds(limit: 0).isEmpty)
    }

    // MARK: - Scheduling

    // Getting it right pushes the kanji further out each time, so a well-retained burn stops
    // eating session slots.
    @Test func recordCorrect_advancesStageAndPushesDueDate() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))

        store.recordCorrect(subjectId: 1)

        #expect(store.newCount == 0)   // now practiced
        #expect(store.dueCount == 0)   // and scheduled into the future, not still due
        // Stage 1 → 1 day out, so it's no longer the top pick over an overdue kanji.
        insert(context, subjectId: 2, stage: 2,
               dueAt: Date().addingTimeInterval(-60 * 60 * 24), firstPracticedAt: Date())
        #expect(store.prioritizedSubjectIds(limit: 10) == [2, 1])
    }

    // A miss drops two stages but never falls back into the "new" bucket — the kanji comes back
    // tomorrow rather than jumping ahead of genuinely new burns.
    @Test func recordIncorrect_dropsStageButStaysPracticed() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let now = Date()
        insert(context, subjectId: 1, stage: 5, dueAt: now, firstPracticedAt: now)

        store.recordIncorrect(subjectId: 1)

        let entry = try #require(
            try context.fetch(FetchDescriptor<BurnedKanjiSRSEntry>()).first
        )
        #expect(entry.stage == 3)
        #expect(entry.totalIncorrect == 1)
        #expect(entry.consecutiveCorrect == 0)
        #expect(entry.dueAt > now)
        #expect(store.newCount == 0)
    }

    // Floor at stage 1: missing a stage-0 or stage-1 kanji reschedules it for tomorrow rather than
    // stage 0's "due immediately", which would loop it inside a single session.
    @Test func recordIncorrect_flooredAtStageOne() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))

        store.recordIncorrect(subjectId: 1)

        let entry = try #require(
            try context.fetch(FetchDescriptor<BurnedKanjiSRSEntry>()).first
        )
        #expect(entry.stage == 1)
        #expect(entry.dueAt > Date())
        #expect(store.dueCount == 0)
    }

    // The whole point of the queue is catching a fade, and due date doesn't know which kanji is
    // fading — a shaky one and a solid one come around on the same schedule. Accuracy has to lead
    // inside each bucket, with due-ness still ahead of not-due.
    @Test func prioritized_weakestFirstWithinEachBucket() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let now = Date()
        let day: TimeInterval = 60 * 60 * 24

        // Due: 1 is the most overdue but nearly perfect; 2 is the one actually being missed.
        insert(context, subjectId: 1, stage: 4, dueAt: now.addingTimeInterval(-day * 20),
               firstPracticedAt: now, totalCorrect: 9, totalIncorrect: 0)
        insert(context, subjectId: 2, stage: 1, dueAt: now.addingTimeInterval(-day),
               firstPracticedAt: now, totalCorrect: 1, totalIncorrect: 4)
        // Not due: same split again, to check the filler bucket ranks the same way.
        insert(context, subjectId: 3, stage: 5, dueAt: now.addingTimeInterval(day),
               firstPracticedAt: now, totalCorrect: 6, totalIncorrect: 0)
        insert(context, subjectId: 4, stage: 5, dueAt: now.addingTimeInterval(day * 2),
               firstPracticedAt: now, totalCorrect: 2, totalIncorrect: 3)

        #expect(store.prioritizedSubjectIds(limit: 10) == [2, 1, 4, 3])

        // A short session spends its slots on the weakest due kanji, not the oldest.
        #expect(store.prioritizedSubjectIds(limit: 1) == [2])
    }

    // MARK: - Stats

    // The stats screen reads its whole "good at vs bad at" split out of these totals, so a mixed
    // practice record has to survive the round trip intact.
    @Test func stats_carryPracticeRecord() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        store.sync(assignments: try assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
            (subjectId: 2, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))

        store.recordCorrect(subjectId: 1)
        store.recordCorrect(subjectId: 1)
        store.recordIncorrect(subjectId: 1)
        // Kanji 2 is left untouched — burned on WaniKani but never practiced here.

        let stats = store.stats()
        let first = try #require(stats.first { $0.subjectId == 1 })
        let second = try #require(stats.first { $0.subjectId == 2 })

        #expect(first.totalCorrect == 2)
        #expect(first.totalIncorrect == 1)
        #expect(first.attempts == 3)
        #expect(first.isPracticed)
        #expect(first.accuracy == 2.0 / 3.0)

        // Never quizzed here: no record, so it belongs in neither ranking.
        #expect(!second.isPracticed)
        #expect(second.accuracy == nil)
        #expect(second.attempts == 0)
    }

    // Raw accuracy ties 1/1 with 20/20 and 0/1 with 0/5, which would let a single lucky or unlucky
    // answer top either list. Ranking has to break those ties by weight of evidence.
    @Test func rankScore_ordersByEvidenceWhenAccuracyTies() {
        func stat(correct: Int, incorrect: Int) -> BurnedKanjiStat {
            BurnedKanjiStat(
                subjectId: 1, stage: 1, dueAt: .distantPast, burnedAt: nil,
                lastPracticedAt: nil, totalCorrect: correct, totalIncorrect: incorrect,
                consecutiveCorrect: correct
            )
        }

        // Strongest: a long clean streak beats a single right answer.
        #expect(stat(correct: 20, incorrect: 0).rankScore > stat(correct: 1, incorrect: 0).rankScore)
        // Needs Work: five misses sink below one miss.
        #expect(stat(correct: 0, incorrect: 5).rankScore < stat(correct: 0, incorrect: 1).rankScore)
        // Accuracy still dominates across different records.
        #expect(stat(correct: 9, incorrect: 1).rankScore > stat(correct: 1, incorrect: 9).rankScore)
        // An unpracticed kanji lands mid-scale rather than at either extreme.
        #expect(stat(correct: 0, incorrect: 0).rankScore == 0.5)
    }

    // Lifetime misses never decrease, so without a way back a single miss would pin a kanji to
    // "Needs Work" for good however well it was known afterwards. The streak is that way back.
    @Test func streak_clearsAPastMiss() {
        func stat(correct: Int, incorrect: Int, streak: Int) -> BurnedKanjiStat {
            BurnedKanjiStat(
                subjectId: 1, stage: 1, dueAt: .distantPast, burnedAt: nil,
                lastPracticedAt: nil, totalCorrect: correct, totalIncorrect: incorrect,
                consecutiveCorrect: streak
            )
        }
        let needed = BurnedKanjiStat.redemptionStreak

        // A clean record is strong from the first answer — the streak rule only gates recovery.
        let clean = stat(correct: 1, incorrect: 0, streak: 1)
        #expect(clean.isStrong)
        #expect(!clean.needsWork)
        #expect(!clean.isRecovered)

        // One short of the streak: still carrying the miss, and the row says how much is left.
        let almost = stat(correct: 1 + needed - 1, incorrect: 2, streak: needed - 1)
        #expect(almost.needsWork)
        #expect(!almost.isStrong)
        #expect(almost.answersToRecover == 1)

        // Hitting the streak moves it across, flagged as recovered rather than clean.
        let recovered = stat(correct: 1 + needed, incorrect: 2, streak: needed)
        #expect(recovered.isStrong)
        #expect(!recovered.needsWork)
        #expect(recovered.isRecovered)
        #expect(recovered.answersToRecover == 0)

        // A fresh miss zeroes the streak, so it drops back and starts the climb over.
        let missedAgain = stat(correct: 1 + needed, incorrect: 3, streak: 0)
        #expect(missedAgain.needsWork)
        #expect(missedAgain.answersToRecover == needed)

        // An unpracticed kanji is in neither list, whatever the streak field says.
        #expect(!stat(correct: 0, incorrect: 0, streak: 0).isStrong)
        #expect(!stat(correct: 0, incorrect: 0, streak: 0).needsWork)
    }

    // The same journey through the store, since recovery depends on recordCorrect/recordIncorrect
    // keeping the streak the stats screen reads.
    @Test func streak_recoversThroughTheStore() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        store.sync(assignments: try assignments([
            (subjectId: 1, srsStage: 9, burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))

        store.recordIncorrect(subjectId: 1)
        #expect(try #require(store.stats().first).needsWork)

        for _ in 1..<BurnedKanjiStat.redemptionStreak {
            store.recordCorrect(subjectId: 1)
        }
        #expect(try #require(store.stats().first).needsWork)

        store.recordCorrect(subjectId: 1)
        let cleared = try #require(store.stats().first)
        #expect(cleared.isStrong)
        #expect(cleared.isRecovered)

        // And a later miss sends it straight back.
        store.recordIncorrect(subjectId: 1)
        #expect(try #require(store.stats().first).needsWork)
    }

    // The chart renders one bar per stage, so the counts must be the full interval table wide even
    // when most stages are empty.
    @Test func stageCounts_bucketEveryStage() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let now = Date()

        insert(context, subjectId: 1, stage: 0, dueAt: now, firstPracticedAt: nil)
        insert(context, subjectId: 2, stage: 3, dueAt: now, firstPracticedAt: now)
        insert(context, subjectId: 3, stage: 3, dueAt: now, firstPracticedAt: now)

        let counts = store.stageCounts()

        #expect(counts.count == BurnedKanjiSRSStore.intervalDays.count)
        #expect(counts[0] == 1)
        #expect(counts[3] == 2)
        #expect(counts.reduce(0, +) == 3)
    }

    // Labels are derived from the interval table so the chart can't drift out of step with the
    // schedule it's describing.
    @Test func stageLabel_derivesFromIntervalTable() {
        #expect(BurnedKanjiSRSStore.stageLabel(0) == "New")
        #expect(BurnedKanjiSRSStore.stageLabel(1) == "1d")
        #expect(BurnedKanjiSRSStore.stageLabel(BurnedKanjiSRSStore.intervalDays.count - 1) == "180d")
        // Out of range falls back rather than trapping.
        #expect(BurnedKanjiSRSStore.stageLabel(99) == "New")
    }

    // Stage is capped so the interval table is never indexed out of bounds.
    @Test func recordCorrect_capsAtMaxStage() throws {
        let context = try makeContext()
        let store = BurnedKanjiSRSStore(context: context)
        let maxStage = BurnedKanjiSRSStore.intervalDays.count - 1
        insert(context, subjectId: 1, stage: maxStage, dueAt: Date(), firstPracticedAt: Date())

        store.recordCorrect(subjectId: 1)
        store.recordCorrect(subjectId: 1)

        let entry = try #require(
            try context.fetch(FetchDescriptor<BurnedKanjiSRSEntry>()).first
        )
        #expect(entry.stage == maxStage)
        #expect(entry.totalCorrect == 2)
    }
}
