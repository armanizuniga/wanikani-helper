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
                guard let sentence = BundledSentenceStore.shared.randomSentence(for: w.id) else { return nil }
                let chars = w.characters ?? w.slug ?? "?"
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

        if AIModelManager.shared.activeBackend == .claude {
            var attempts = 0
            while attempts < 3 {
                do {
                    let result = try await ClaudeBackend.shared.generateSentence(
                        targetWord: characters, reading: reading, meaning: meaning, userLevel: level
                    )
                    if sentenceContainsWord(characters, in: result.japanese) {
                        // Persist into the pre-generated pool so it accumulates over time.
                        SavedSentenceStore.shared.append(result.japanese, for: word.id)
                        state = .result(result, vocabWord: characters, meaning: meaning)
                        return
                    }
                } catch {
                    // network / API error — retry
                }
                attempts += 1
            }
            state = .failed
            return
        }

        let userPrompt = "Write a sentence using \(characters)."

        var attempts = 0
        while attempts < 5 {
            do {
                let result = try await AIModelManager.shared.currentBackend.generate(
                    systemPrompt: PromptLibrary.shared.compose(word: characters, reading: reading, meaning: meaning),
                    userPrompt: userPrompt
                )
                if sentenceContainsWord(characters, in: result.japanese) {
                    state = .result(result, vocabWord: characters, meaning: meaning)
                    return
                }
            } catch {
                // safety guardrail or model error — retry with a fresh grammar prompt
            }
            attempts += 1
        }
        state = .failed
    }

    func reset() { state = .idle }
}
