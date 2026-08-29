// Drives the Name Practice quiz: reading Japanese names, which WaniKani never teaches
// because name readings (nanori) mostly aren't the on/kun readings its subjects cover.
//
// Local-only, like KanjiReviewService: nothing is submitted, no SRS is touched.
import Foundation
import Observation

enum NameMode: String, CaseIterable, Identifiable {
    case surname, given, full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .surname: return "Surnames"
        case .given:   return "Given Names"
        case .full:    return "Full Names"
        }
    }

    var detail: String {
        switch self {
        case .surname: return "The 100 most common family names."
        case .given:   return "Common given names, male and female."
        case .full:    return "A surname paired with a given name, the way you'd see it written."
        }
    }
}

/// One quiz card: a name to read, four candidate readings, and the breakdown to reveal.
struct NameQuestion: Identifiable {
    let id = UUID()
    let kanji: String
    let reading: String
    let romaji: String
    let segments: [NameSegment]
    let choices: [String]

    var selected: String?
    var answered = false
    var isCorrect: Bool? { selected.map { $0 == reading } }
}

@Observable
@MainActor
final class NamePracticeService {
    private(set) var queue: [NameQuestion] = []
    private(set) var currentIndex = 0
    private(set) var sessionComplete = false

    static let sessionLength = 20

    private let store = NameStore.shared

    var current: NameQuestion? {
        currentIndex < queue.count ? queue[currentIndex] : nil
    }

    var correctCount: Int { queue.filter { $0.isCorrect == true }.count }
    var answeredCount: Int { queue.filter { $0.answered }.count }
    var totalCount: Int { queue.count }

    // MARK: - Session

    /// Builds a session by drawing without replacement, so no name is asked twice.
    /// Picking randomly per question repeats often at these pool sizes: 20 draws from
    /// 100 surnames collides more than 85% of the time by the birthday paradox.
    func start(mode: NameMode) {
        switch mode {
        case .surname:
            queue = store.surnames.shuffled()
                .prefix(Self.sessionLength)
                .map { single($0, pool: store.surnames) }
        case .given:
            queue = store.givenNames.shuffled()
                .prefix(Self.sessionLength)
                .map { single($0, pool: store.givenNames) }
        case .full:
            // Zipping two independent shuffles keeps every pair distinct and, as a bonus,
            // never repeats a surname or a given name within the session either.
            queue = zip(store.surnames.shuffled(), store.givenNames.shuffled())
                .prefix(Self.sessionLength)
                .map { full(surname: $0.0, given: $0.1) }
        }
        currentIndex = 0
        sessionComplete = false
    }

    private func single(_ name: JapaneseName, pool: [JapaneseName]) -> NameQuestion {
        // Prefer distractors of the same reading length so the answer can't be picked on shape.
        let others = pool.filter { $0.reading != name.reading }
        let sameLength = others.filter { $0.reading.count == name.reading.count }
        let source = sameLength.count >= 3 ? sameLength : others
        let distractors = Array(source.shuffled().prefix(3)).map(\.reading)

        return NameQuestion(
            kanji: name.kanji,
            reading: name.reading,
            romaji: name.romaji,
            segments: name.segments ?? [],
            choices: ([name.reading] + distractors).shuffled()
        )
    }

    private func full(surname: JapaneseName, given: JapaneseName) -> NameQuestion {
        let reading = surname.reading + given.reading

        // Distractors swap exactly one half, so both halves have to be read to answer.
        // Four unrelated readings would let you win by recognising the surname alone.
        var wrong: Set<String> = []
        for other in store.givenNames.shuffled() where wrong.count < 2 {
            let candidate = surname.reading + other.reading
            if candidate != reading { wrong.insert(candidate) }
        }
        for other in store.surnames.shuffled() where wrong.count < 3 {
            let candidate = other.reading + given.reading
            if candidate != reading { wrong.insert(candidate) }
        }

        return NameQuestion(
            kanji: surname.kanji + given.kanji,
            reading: reading,
            romaji: surname.romaji + " " + given.romaji,
            segments: (surname.segments ?? []) + (given.segments ?? []),
            choices: ([reading] + wrong).shuffled()
        )
    }

    // MARK: - Answering

    func select(_ choice: String) {
        guard currentIndex < queue.count, queue[currentIndex].selected == nil else { return }
        queue[currentIndex].selected = choice
    }

    func advance() {
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
