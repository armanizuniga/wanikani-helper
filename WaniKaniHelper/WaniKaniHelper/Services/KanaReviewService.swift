// Manages the state of a kana practice session (hiragana or katakana).
// Draws characters from KanaSRSStore using weighted selection that favors less-mastered characters,
// grades romanization input, and updates mastery levels on correct or incorrect answers.
import Foundation
import Observation

enum KanaAnswerResult {
    case correct
    case incorrect(correctAnswer: String)
}

@Observable
@MainActor
final class KanaReviewService {
    let script: String
    private let store: KanaSRSStore

    private(set) var currentEntry: KanaSRSEntry?
    private(set) var choices: [String] = []
    private(set) var selectedChoice: String?
    private(set) var answerResult: KanaAnswerResult?
    private(set) var sessionCorrect = 0
    private(set) var sessionIncorrect = 0
    private var lastCharacter: String?

    init(store: KanaSRSStore, script: String) {
        self.store = store
        self.script = script
    }

    var isAnswered: Bool { answerResult != nil }
    var masteredCount: Int { store.masteredCount(script: script) }
    var totalCount: Int { store.totalCount(script: script) }

    func loadNext() {
        lastCharacter = currentEntry?.character
        currentEntry = store.nextItem(script: script, excluding: lastCharacter)
        selectedChoice = nil
        answerResult = nil
        if let entry = currentEntry {
            choices = generateChoices(for: entry)
        }
    }

    func selectChoice(_ romaji: String) {
        guard !isAnswered, let entry = currentEntry else { return }
        selectedChoice = romaji
        let accepted = store.romajiFor(character: entry.character)

        if accepted.contains(romaji) {
            answerResult = .correct
            sessionCorrect += 1
            store.recordCorrect(entry: entry)
        } else {
            answerResult = .incorrect(correctAnswer: accepted.first ?? "?")
            sessionIncorrect += 1
            store.recordIncorrect(entry: entry)
        }
    }

    func advance() {
        loadNext()
    }

    // MARK: - Choice generation

    private func generateChoices(for entry: KanaSRSEntry) -> [String] {
        let correct = KanaData.primaryRomaji(for: entry.character)
        let pool = (script == "hiragana" ? KanaData.allHiragana : KanaData.allKatakana)
            .compactMap { $0.romaji.first }
            .filter { $0 != correct }

        let distractors = Array(pool.shuffled().prefix(3))
        return ([correct] + distractors).shuffled()
    }
}
