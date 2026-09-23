// On-device AI service that generates a Japanese reading-practice sentence for the home screen
// Daily Sentence card. Delegates to whichever AIBackend is active in AIModelManager.
import Foundation
import Observation

@Observable
@MainActor
final class SentenceGeneratorService {
    enum GeneratorState {
        case idle
        case generating
        case result(AIGeneratedContent, vocabWord: String, meaning: String)
        case failed
    }

    private(set) var state: GeneratorState = .idle

    static var isSupported: Bool { AIModelManager.shared.isAnyBackendAvailable }

    func generate(store: SubjectStore, level: Int) async {
        let vocab = store.subjects(level: level).filter { $0.subjectType.isVocab }
        guard !vocab.isEmpty else { return }

        state = .generating

        if AIModelManager.shared.activeBackend == .bundled {
            let candidates = vocab.compactMap { w -> (String, String, String)? in
                let chars = w.characters ?? w.slug ?? "?"
                guard let sentence = BundledSentenceStore.shared.bestSentence(for: w.id, target: chars) else { return nil }
                let meaning = w.meanings.first ?? "?"
                return (chars, meaning, sentence)
            }
            if let (chars, meaning, sentence) = candidates.randomElement() {
                state = .result(AIGeneratedContent(japanese: sentence), vocabWord: chars, meaning: meaning)
            } else {
                state = .failed
            }
            return
        }

        guard let word = vocab.randomElement() else { return }
        let characters = word.characters ?? word.slug ?? "?"
        let meaning    = word.meanings.first ?? "?"
        let reading    = word.readings.first

        // Both paths keep the attempt with the fewest kanji the user hasn't mastered (see KnownKanji).
        if AIModelManager.shared.activeBackend == .claude {
            let best = await bestKnownKanjiSentence(target: characters, maxAttempts: 3) {
                try await ClaudeBackend.shared.generateSentence(
                    targetWord: characters, reading: reading, meaning: meaning, userLevel: level
                )
            }
            if let best {
                // Persist into the pre-generated pool so it accumulates over time.
                SavedSentenceStore.shared.append(best.japanese, for: word.id)
                state = .result(best, vocabWord: characters, meaning: meaning)
            } else {
                state = .failed
            }
            return
        }

        let userPrompt = "Write a sentence using \(characters)."

        // Each attempt composes a fresh grammar prompt, so retries also vary the grammar point.
        let best = await bestKnownKanjiSentence(target: characters, maxAttempts: 5) {
            try await AIModelManager.shared.currentBackend.generate(
                systemPrompt: PromptLibrary.shared.compose(word: characters, reading: reading, meaning: meaning),
                userPrompt: userPrompt
            )
        }
        if let best {
            state = .result(best, vocabWord: characters, meaning: meaning)
        } else {
            state = .failed
        }
    }

    func reset() { state = .idle }
}
