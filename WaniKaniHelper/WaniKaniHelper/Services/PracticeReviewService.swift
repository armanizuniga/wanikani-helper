// Drives the local practice features — Kanji Review and Vocab Review — a self-quiz over the user's
// own subjects, filtered by SRS-stage category (Apprentice / Guru / Master / Enlightened / Burned).
//
// One service covers both: `kind` decides which subject types are fetched and how the screens read,
// and `burnedStore` is whichever local burned schedule belongs to that kind.
//
// Unlike ReviewService, this NEVER submits to WaniKani and never changes SRS state or the daily
// goal — burned/enlightened items can't be reviewed on WaniKani, and this is pure practice.
import Foundation
import Observation

@Observable
@MainActor
final class PracticeReviewService {
    let kind: PracticeKind

    // Category-selection screen state.
    private(set) var counts: [SRSCategory: Int] = [:]
    private var poolsBySubject: [SRSCategory: [Int]] = [:]
    private(set) var isLoadingCategories = false
    private(set) var categoryError: String?

    // Quiz state.
    private(set) var queue: [ReviewItem] = []
    private(set) var currentIndex = 0
    private(set) var sessionComplete = false
    private(set) var sessionStarted = false

    /// Subject ids in the current session that came from the burned pool, so results are only
    /// recorded for those — practice on other categories doesn't feed the burned schedule.
    private var burnedSubjectIds: Set<Int> = []

    private let api = WaniKaniAPIClient.shared
    private let store: SubjectStore
    private let burnedStore: any BurnedSRSStoring

    /// Subjects per session. Short on purpose: the cards are recall practice on mastered material,
    /// and a session that ends is worth more than one that gets abandoned.
    static let sessionCap = 15

    /// WaniKani `subject_types` filter for this kind. Vocabulary covers both the kanji-bearing
    /// words and the kana-only ones, which WaniKani models as separate subject types.
    private var subjectTypes: String {
        switch kind {
        case .kanji:      return "kanji"
        case .vocabulary: return "vocabulary,kana_vocabulary"
        }
    }

    init(kind: PracticeKind, store: SubjectStore, burnedStore: any BurnedSRSStoring) {
        self.kind = kind
        self.store = store
        self.burnedStore = burnedStore
    }

    var current: ReviewItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    // Progress is tracked per subject (one card each, so this is also the card count).
    var completedCount: Int {
        let grouped = Dictionary(grouping: queue, by: { $0.subjectId })
        return grouped.filter { _, cards in cards.allSatisfy { $0.answered } }.count
    }

    var totalCount: Int { Set(queue.map { $0.subjectId }).count }

    func count(for category: SRSCategory) -> Int { counts[category] ?? 0 }

    var hasAnySubjects: Bool { counts.values.contains { $0 > 0 } }

    // MARK: - Load categories

    func loadCategories() async {
        isLoadingCategories = true
        categoryError = nil
        defer { isLoadingCategories = false }

        do {
            let assignments = try await api.fetchAssignments(subjectTypes: subjectTypes)
            var newCounts: [SRSCategory: Int] = [:]
            var newPools: [SRSCategory: [Int]] = [:]
            for resource in assignments where !resource.data.hidden {
                guard let category = SRSCategory.category(for: resource.data.srsStage) else { continue }
                newCounts[category, default: 0] += 1
                newPools[category, default: []].append(resource.data.subjectId)
            }
            counts = newCounts
            poolsBySubject = newPools
            // Same assignments, no extra request: keep the local burned schedule in step with
            // WaniKani (new burns in, resurrected items out).
            burnedStore.sync(assignments: assignments)
        } catch {
            if error.isNetworkFailure {
                categoryError = "You're offline. \(kind.reviewTitle) needs a connection to load your progress."
            } else {
                categoryError = error.localizedDescription
            }
        }
    }

    func selectedTotal(_ categories: Set<SRSCategory>) -> Int {
        var ids = Set<Int>()
        for category in categories { ids.formUnion(poolsBySubject[category] ?? []) }
        return ids.count
    }

    // MARK: - Start session

    func startSession(categories: Set<SRSCategory>) {
        // Burned subjects are drawn from the local SRS schedule (new burns first, then weakest)
        // rather than at random, so repeat sessions keep surfacing new material and whatever is
        // fading. Everything else is still a random draw — nothing tracks per-subject accuracy
        // outside the burned schedule.
        var selectedIds: [Int] = []
        if categories.contains(.burned) {
            selectedIds = burnedStore.prioritizedSubjectIds(limit: Self.sessionCap)
        }
        burnedSubjectIds = Set(selectedIds)

        var otherIds = Set<Int>()
        for category in categories where category != .burned {
            otherIds.formUnion(poolsBySubject[category] ?? [])
        }
        otherIds.subtract(burnedSubjectIds)
        selectedIds += otherIds.shuffled().prefix(max(0, Self.sessionCap - selectedIds.count))

        let subjectMap = store.subjectMap(ids: selectedIds)
        let subjects = selectedIds.compactMap { subjectMap[$0] }

        // Meaning-only practice — one card per subject (no reading/pronunciation question).
        // Kept in selection order rather than shuffled: burned items arrive weakest-first from the
        // local schedule, and that's the order worth asking them in while attention is fresh.
        var items: [ReviewItem] = subjects.map { subject in
            ReviewItem(
                id: subject.id, assignmentId: subject.id, subjectId: subject.id,
                subject: subject, questionType: .meaning
            )
        }

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

        // Feed the local burned schedule so this subject comes back sooner if missed, later if not.
        let item = queue[currentIndex]
        if burnedSubjectIds.contains(item.subjectId), let correct = item.choiceWasCorrect {
            if correct {
                burnedStore.recordCorrect(subjectId: item.subjectId)
            } else {
                burnedStore.recordIncorrect(subjectId: item.subjectId)
            }
        }

        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else {
            sessionComplete = true
        }
    }

    func endSessionEarly() { sessionComplete = true }
}
