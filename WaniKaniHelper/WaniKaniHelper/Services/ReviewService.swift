// Manages the state of a WaniKani review session. Fetches available assignments, builds a queue
// of meaning and reading ReviewItems with multiple-choice distractors, grades answers, submits
// results to the WaniKani API, and tracks session statistics (correct, incorrect, items reviewed).
import Foundation
import Observation

// Persistent review preferences. Easy Mode drops the reading question from normal WaniKani
// reviews: kanji/vocab become meaning-only (like radicals already are), and the reading is
// submitted to WaniKani as correct so real SRS advances on the meaning answer alone.
enum ReviewSettings {
    static let easyModeKey = "reviewEasyMode"
    static var easyMode: Bool { UserDefaults.standard.bool(forKey: easyModeKey) }
}

@Observable
@MainActor
final class ReviewService {
    private(set) var queue: [ReviewItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var error: String?
    private(set) var networkWarning: String?
    private(set) var sessionComplete: Bool = false

    private let api = WaniKaniAPIClient.shared
    private let store: SubjectStore

    init(store: SubjectStore) {
        self.store = store
    }

    var current: ReviewItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    // Unique assignments where every card for that assignment is answered
    var completedAssignmentCount: Int {
        let allIds = Dictionary(grouping: queue, by: { $0.assignmentId })
        return allIds.filter { _, cards in cards.allSatisfy { $0.answered } }.count
    }

    var totalAssignmentCount: Int {
        Set(queue.map { $0.assignmentId }).count
    }

    // MARK: - Load

    func loadQueue() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let assignments = try await api.fetchAvailableAssignments()
            let subjectIds = assignments.map { $0.data.subjectId }
            let subjectMap = store.subjectMap(ids: subjectIds)

            // Build paired cards per assignment
            var pairs: [(meaning: ReviewItem, reading: ReviewItem?)] = []

            for assignment in assignments {
                guard let subject = subjectMap[assignment.data.subjectId] else { continue }
                let aId = assignment.id ?? 0

                let meaningCard = ReviewItem(
                    id: aId * 2,
                    assignmentId: aId,
                    subjectId: assignment.data.subjectId,
                    subject: subject,
                    questionType: .meaning
                )

                // Radicals and kana vocabulary have no reading question. In Easy Mode, drop the
                // reading question for everything — the assignment submits on meaning alone.
                let needsReading = subject.subjectType.hasReading && !ReviewSettings.easyMode
                let readingCard: ReviewItem? = needsReading ? ReviewItem(
                    id: aId * 2 + 1,
                    assignmentId: aId,
                    subjectId: assignment.data.subjectId,
                    subject: subject,
                    questionType: .reading
                ) : nil

                pairs.append((meaningCard, readingCard))
            }

            // Interleave a group of pairs: each meaning card lands in a random slot across
            // [0, 2N), with its reading card placed 3–15 slots after. Sorting by slot interleaves.
            func interleaved(_ groupPairs: [(meaning: ReviewItem, reading: ReviewItem?)]) -> [ReviewItem] {
                let shuffledPairs = groupPairs.shuffled()
                let N = shuffledPairs.count
                guard N > 0 else { return [] }
                let meaningSlots = Array(0..<(N * 2)).shuffled().prefix(N).sorted()

                var slots: [(slot: Int, card: ReviewItem)] = []
                for (i, pair) in shuffledPairs.enumerated() {
                    let mSlot = meaningSlots[i]
                    slots.append((mSlot, pair.meaning))
                    if let reading = pair.reading {
                        slots.append((mSlot + Int.random(in: 3...15), reading))
                    }
                }
                slots.sort { $0.slot < $1.slot }
                return slots.map { $0.card }
            }

            // Prioritize kanji: all kanji cards come first, then radicals and vocab intermixed.
            let kanjiPairs = pairs.filter { $0.meaning.subject.subjectType == .kanji }
            let otherPairs = pairs.filter { $0.meaning.subject.subjectType != .kanji }
            var items = interleaved(kanjiPairs) + interleaved(otherPairs)

            // Build choice pools
            let allMeanings = items
                .filter { $0.questionType == QuestionType.meaning }
                .compactMap { $0.subject.meanings.first }
            let allReadings = items
                .filter { $0.questionType == QuestionType.reading }
                .compactMap { $0.subject.readings.first }

            let extraMeanings = store.distractorMeanings(excluding: -1, count: 20)
            let extraReadings = store.distractorReadings(excluding: -1, count: 20)

            let meaningPool = Array(Set(allMeanings + extraMeanings))
            let readingPool  = Array(Set(allReadings  + extraReadings))

            for i in items.indices {
                if items[i].questionType == QuestionType.meaning {
                    let correct = items[i].subject.meanings.first ?? "?"
                    let distractors = meaningPool.filter { $0 != correct }.shuffled().prefix(3)
                    items[i].correctChoice = correct
                    items[i].choices = ([correct] + Array(distractors)).shuffled()
                } else {
                    let correct = items[i].subject.readings.first ?? "?"
                    let distractors = readingPool.filter { $0 != correct }.shuffled().prefix(3)
                    items[i].correctChoice = correct
                    items[i].choices = ([correct] + Array(distractors)).shuffled()
                }
            }

            queue = items
            currentIndex = 0
            sessionComplete = false
        } catch {
            if error.isNetworkFailure {
                networkWarning = "Offline: Progress can't be saved"
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    func clearNetworkWarning() {
        networkWarning = nil
    }

    func endSessionEarly() {
        sessionComplete = true
    }

    // MARK: - Review Mode

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

        let item = queue[currentIndex]
        let assignmentCards = queue.filter { $0.assignmentId == item.assignmentId }
        if assignmentCards.allSatisfy({ $0.answered }) {
            Task { await submitAssignment(assignmentId: item.assignmentId, cards: assignmentCards) }
        }

        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else {
            sessionComplete = true
        }
    }

    private func submitAssignment(assignmentId: Int, cards: [ReviewItem]) async {
        let incorrectMeaning = cards.filter { $0.questionType == QuestionType.meaning }.reduce(0) { $0 + $1.incorrectCount }
        let incorrectReading  = cards.filter { $0.questionType == QuestionType.reading  }.reduce(0) { $0 + $1.incorrectCount }
        let subjectId = cards.first?.subjectId ?? 0

        for _ in 1...3 {
            do {
                let response = try await api.submitReview(
                    assignmentId: assignmentId,
                    incorrectMeaning: incorrectMeaning,
                    incorrectReading: incorrectReading
                )
                updateSubjectStatus(subjectId: subjectId, response: response)
                DailyGoal.increment(by: 1)
                return
            } catch WaniKaniError.rateLimited {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                if error.isNetworkFailure {
                    networkWarning = "Offline: Progress can't be saved"
                } else {
                    self.error = error.localizedDescription
                }
                return
            }
        }
    }

    private func updateSubjectStatus(subjectId: Int, response: WKReviewResponse) {
        if response.data.endingSrsStage >= SRSStage.burned {
            store.markBurned(subjectId: subjectId)
        } else if response.data.endingSrsStage >= SRSStage.passed {
            store.markPassed(subjectId: subjectId)
        }
    }
}
