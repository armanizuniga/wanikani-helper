// Tests for the local SRS schedule over burned vocabulary.
//
// The schedule logic itself lives in the generic `BurnedSRSStore` and is pinned down in detail by
// BurnedKanjiSRSStoreTests. What is unproven by those is the other half of the generic: whether the
// same class, instantiated over `BurnedVocabSRSEntry`, actually reaches the vocabulary table.
//
// That is not a formality. Each model supplies its own `#Predicate` factories — the macro can't be
// written against a generic parameter — so counting, looking an entry up and recording a result all
// run through per-model code that nothing else exercises. These tests walk one word through sync,
// selection and scoring to confirm that path is wired to the right table and behaves like the kanji
// one.
import Testing
import Foundation
import SwiftData
@testable import WaniKaniHelper

@MainActor
struct BurnedVocabSRSStoreTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BurnedVocabSRSEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Assignment resources as the API layer would produce them. `subject_type` is a real
    /// vocabulary type here, which is what a vocab session actually receives.
    private func assignments(
        _ specs: [(subjectId: Int, srsStage: Int, subjectType: String, burnedAt: String?)]
    ) throws -> [WKResource<WKAssignmentData>] {
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
                "subject_type": "\(spec.subjectType)",
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

    // MARK: - Tests

    // Kana-only words are a separate WaniKani subject type from kanji-bearing vocabulary, and a
    // vocab session asks for both. Burn state is what decides tracking, not which of the two it is.
    @Test func sync_tracksBurnedVocabularyOfEitherSubjectType() throws {
        let context = try makeContext()
        let store = BurnedVocabSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, subjectType: "vocabulary", burnedAt: "2026-08-01T00:00:00.000000Z"),
            (subjectId: 2, srsStage: 9, subjectType: "kana_vocabulary", burnedAt: "2026-08-02T00:00:00.000000Z"),
            (subjectId: 3, srsStage: 8, subjectType: "vocabulary", burnedAt: nil),  // enlightened
        ]))

        #expect(store.trackedCount == 2)
        #expect(Set(store.stats().map(\.subjectId)) == [1, 2])
    }

    // A fresh burn has never been practiced here, so it counts as new rather than due, and comes
    // out of selection straight away.
    @Test func newBurnIsUnpracticedAndImmediatelySelectable() throws {
        let context = try makeContext()
        let store = BurnedVocabSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 7, srsStage: 9, subjectType: "vocabulary", burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))

        #expect(store.newCount == 1)
        #expect(store.dueCount == 0)
        #expect(store.prioritizedSubjectIds(limit: 15) == [7])
    }

    // The whole point of the vocab schedule: an answer has to land on the vocabulary entry, move
    // its stage, and show up in that word's record.
    @Test func recordingResultsUpdatesTheVocabularyEntry() throws {
        let context = try makeContext()
        let store = BurnedVocabSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 42, srsStage: 9, subjectType: "vocabulary", burnedAt: nil),
        ]))

        store.recordCorrect(subjectId: 42)
        var stat = try #require(store.stats().first)
        #expect(stat.stage == 1)
        #expect(stat.totalCorrect == 1)
        #expect(stat.consecutiveCorrect == 1)
        // Practiced and pushed a day out, so it's no longer new and not yet due.
        #expect(store.newCount == 0)
        #expect(store.dueCount == 0)

        store.recordIncorrect(subjectId: 42)
        stat = try #require(store.stats().first)
        #expect(stat.totalIncorrect == 1)
        #expect(stat.consecutiveCorrect == 0)
        #expect(stat.stage == 1)          // floored at 1, same as the kanji schedule
        #expect(stat.needsWork)
    }

    // The app builds both stores over one shared ModelContext, which the per-store tests above
    // don't reproduce. Kanji and vocabulary ids come from the same WaniKani id space, so if the two
    // schedules ever read each other's rows, a kanji would surface in a vocab session and results
    // would be written against the wrong record.
    @Test func schedulesStaySeparateInASharedContainer() throws {
        let container = try ModelContainer(
            for: BurnedKanjiSRSEntry.self, BurnedVocabSRSEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let kanjiStore = BurnedKanjiSRSStore(context: context)
        let vocabStore = BurnedVocabSRSStore(context: context)

        try kanjiStore.sync(assignments: assignments([
            (subjectId: 100, srsStage: 9, subjectType: "kanji", burnedAt: nil),
        ]))
        try vocabStore.sync(assignments: assignments([
            (subjectId: 200, srsStage: 9, subjectType: "vocabulary", burnedAt: nil),
        ]))

        #expect(kanjiStore.stats().map(\.subjectId) == [100])
        #expect(vocabStore.stats().map(\.subjectId) == [200])

        // A result recorded on one schedule must not touch the other, and an id that belongs to
        // the other schedule must not resolve at all.
        vocabStore.recordCorrect(subjectId: 200)
        vocabStore.recordCorrect(subjectId: 100)   // a kanji id — no vocab entry to hit

        #expect(try #require(vocabStore.stats().first).stage == 1)
        #expect(try #require(kanjiStore.stats().first).stage == 0)
        #expect(kanjiStore.trackedCount == 1)
        #expect(vocabStore.trackedCount == 1)
    }

    // Resurrecting a burned word puts it back in WaniKani's own SRS, so it leaves this queue.
    @Test func sync_dropsResurrectedVocabulary() throws {
        let context = try makeContext()
        let store = BurnedVocabSRSStore(context: context)

        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 9, subjectType: "vocabulary", burnedAt: "2026-08-01T00:00:00.000000Z"),
        ]))
        #expect(store.trackedCount == 1)

        try store.sync(assignments: assignments([
            (subjectId: 1, srsStage: 4, subjectType: "vocabulary", burnedAt: nil),
        ]))
        #expect(store.trackedCount == 0)
    }
}
