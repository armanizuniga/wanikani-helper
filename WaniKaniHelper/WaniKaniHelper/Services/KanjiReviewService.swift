// Drives the Kanji Review practice feature: a local-only self-quiz over the user's kanji,
// filtered by SRS-stage category (Apprentice / Guru / Master / Enlightened / Burned).
//
// Unlike ReviewService, this NEVER submits to WaniKani and never changes SRS state or the daily
// goal — burned/enlightened items can't be reviewed on WaniKani, and this is pure practice.
import Foundation
import Observation

@Observable
@MainActor
final class KanjiReviewService {
    // Category-selection screen state.
    private(set) var counts: [KanjiCategory: Int] = [:]
    private var poolsBySubject: [KanjiCategory: [Int]] = [:]
    private(set) var isLoadingCategories = false
    private(set) var categoryError: String?

    // Quiz state.
    private(set) var queue: [ReviewItem] = []
    private(set) var currentIndex = 0
    private(set) var sessionComplete = false
    private(set) var sessionStarted = false

    private let api = WaniKaniAPIClient.shared
    private let store: SubjectStore

    static let sessionCap = 25

    init(store: SubjectStore) { self.store = store }

    var current: ReviewItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    // Progress is tracked per kanji (each kanji = a meaning card + a reading card).
    var completedCount: Int {
        let grouped = Dictionary(grouping: queue, by: { $0.subjectId })
        return grouped.filter { _, cards in cards.allSatisfy { $0.answered } }.count
    }

    var totalCount: Int { Set(queue.map { $0.subjectId }).count }

    func count(for category: KanjiCategory) -> Int { counts[category] ?? 0 }

    var hasAnyKanji: Bool { counts.values.contains { $0 > 0 } }

    // MARK: - Load categories

    func loadCategories() async {
        isLoadingCategories = true
        categoryError = nil
        defer { isLoadingCategories = false }

        do {
            let assignments = try await api.fetchKanjiAssignments()
            var newCounts: [KanjiCategory: Int] = [:]
            var newPools: [KanjiCategory: [Int]] = [:]
            for resource in assignments where !resource.data.hidden {
                guard let category = KanjiCategory.category(for: resource.data.srsStage) else { continue }
                newCounts[category, default: 0] += 1
                newPools[category, default: []].append(resource.data.subjectId)
            }
            counts = newCounts
            poolsBySubject = newPools
        } catch {
            if error.isNetworkFailure {
                categoryError = "You're offline. Kanji Review needs a connection to load your progress."
            } else {
                categoryError = error.localizedDescription
            }
        }
    }

    func selectedTotal(_ categories: Set<KanjiCategory>) -> Int {
        var ids = Set<Int>()
        for category in categories { ids.formUnion(poolsBySubject[category] ?? []) }
        return ids.count
    }

    // MARK: - Start session

    func startSession(categories: Set<KanjiCategory>) {
        var ids = Set<Int>()
        for category in categories { ids.formUnion(poolsBySubject[category] ?? []) }

        let subjectMap = store.subjectMap(ids: Array(ids))
        let subjects = ids.compactMap { subjectMap[$0] }.shuffled().prefix(Self.sessionCap)

        // Meaning-only practice — one card per kanji (no reading/pronunciation question).
        var items: [ReviewItem] = subjects.map { subject in
            ReviewItem(
                id: subject.id, assignmentId: subject.id, subjectId: subject.id,
                subject: subject, questionType: .meaning
            )
        }
        items.shuffle()

        // Choice pool: correct answers from this session plus extra distractors from the store.
        let allMeanings = items.compactMap { $0.subject.meanings.first }
        let meaningPool = Array(Set(allMeanings + store.distractorMeanings(excluding: -1, count: 20)))

        for i in items.indices {
            let correct = items[i].subject.meanings.first ?? "?"
            let distractors = meaningPool.filter { $0 != correct }.shuffled().prefix(3)
            items[i].correctChoice = correct
            items[i].choices = ([correct] + Array(distractors)).shuffled()
        }

        queue = items
        currentIndex = 0
        sessionComplete = false
        sessionStarted = true
    }

    // MARK: - Quiz interaction (local only — no API submission)

    func selectChoice(_ choice: String) {
        guard currentIndex < queue.count, queue[currentIndex].selectedChoice == nil else { return }
        queue[currentIndex].selectedChoice = choice
        if choice != queue[currentIndex].correctChoice {
            queue[currentIndex].incorrectCount += 1
        }
    }

    func confirmAndAdvance() {
        guard currentIndex < queue.count else { return }
        queue[currentIndex].answered = true
        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else {
            sessionComplete = true
        }
    }

    func endSessionEarly() { sessionComplete = true }
}
