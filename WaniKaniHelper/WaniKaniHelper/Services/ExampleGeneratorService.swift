// On-device AI service that generates a single example sentence for a vocabulary word.
// Delegates to whichever AIBackend is active in AIModelManager.
import Foundation
import Observation

@Observable
@MainActor
final class ExampleGeneratorService {
    enum State {
        case idle
        case generating
        case result(AIGeneratedContent)
        case failed
    }

    private(set) var state: State = .idle

    // Grammar explanation + follow-up chat (Claude only) — driven by the inline card.
    enum ExplanationState {
        case idle
        case loading
        case active     // explanation arrived; the chat thread is live
        case failed
    }

    private(set) var explanation: ExplanationState = .idle

    // Conversation shown under the grammar explanation. The first entry is the explanation itself.
    struct ChatMessage: Identifiable {
        let id = UUID()
        enum Role { case user, assistant }
        let role: Role
        let text: String
    }

    private(set) var chat: [ChatMessage] = []
    private(set) var isReplying = false
    private var chatSentence = ""

    static var isSupported: Bool { AIModelManager.shared.isAnyBackendAvailable }

    // Returns the card to its pre-generation state. Used when a Claude card appears so it shows
    // the "Generate example" button instead of the previous card's sentence.
    func reset() {
        state = .idle
        explanation = .idle
        chat = []
    }

    func explainSentence(_ sentence: String) async {
        explanation = .loading
        chat = []
        chatSentence = sentence
        do {
            let text = try await ClaudeBackend.shared.explainSentence(sentence)
            chat = [ChatMessage(role: .assistant, text: text)]
            explanation = .active
        } catch {
            explanation = .failed
        }
    }

    func askFollowUp(_ question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isReplying else { return }
        chat.append(ChatMessage(role: .user, text: trimmed))
        isReplying = true
        do {
            let history = chat.map {
                ClaudeBackend.ChatTurn(role: $0.role == .user ? .user : .assistant, text: $0.text)
            }
            let reply = try await ClaudeBackend.shared.followUp(sentence: chatSentence, history: history)
            chat.append(ChatMessage(role: .assistant, text: reply))
        } catch {
            chat.append(ChatMessage(role: .assistant, text: "Sorry, I couldn't answer that — please try again."))
        }
        isReplying = false
    }

    func generate(subjectId: Int, characters: String, reading: String?, meaning: String, avoiding: [String] = []) async {
        state = .generating
        explanation = .idle   // reset any prior explanation/chat for the new sentence
        chat = []

        if AIModelManager.shared.activeBackend == .bundled {
            if let sentence = BundledSentenceStore.shared.randomSentence(for: subjectId) {
                state = .result(AIGeneratedContent(japanese: sentence))
            } else {
                state = .failed
            }
            return
        }

        if AIModelManager.shared.activeBackend == .claude {
            var attempts = 0
            while attempts < 3 {
                do {
                    let result = try await ClaudeBackend.shared.generateSentence(
                        targetWord: characters, reading: reading, meaning: meaning,
                        userLevel: WKUserData.cachedLevel, avoiding: avoiding
                    )
                    if sentenceContainsWord(characters, in: result.japanese) {
                        // Persist into the pre-generated pool so it accumulates over time.
                        SavedSentenceStore.shared.append(result.japanese, for: subjectId)
                        state = .result(result)
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

        let userPrompt = "\(characters)を使って日本語の文を書いてください。"
        print("[ExampleGenerator] userPrompt: \(userPrompt)")

        do {
            let result = try await AIModelManager.shared.currentBackend.generate(
                systemPrompt: "",
                userPrompt: userPrompt
            )
            state = .result(result)
        } catch {
            state = .failed
        }
    }

    func regenerate(subjectId: Int, characters: String, reading: String?, meaning: String) async {
        // Feed the most recent saved sentences back as an exclusion list so Claude produces a
        // clearly different sentence (different grammar point and scene). Capped to keep tokens low.
        let recent = Array(SavedSentenceStore.shared.sentences(for: subjectId).suffix(6))
        await generate(
            subjectId: subjectId, characters: characters, reading: reading, meaning: meaning,
            avoiding: recent
        )
    }
}

// Returns true if the sentence contains the vocab word or all of its kanji (handles conjugations).
// Kana-only words fall back to a direct contains check.
func sentenceContainsWord(_ word: String, in sentence: String) -> Bool {
    let kanji = word.unicodeScalars.filter {
        ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
        ($0.value >= 0x3400 && $0.value <= 0x4DBF)
    }
    guard !kanji.isEmpty else { return sentence.contains(word) }
    return kanji.allSatisfy { sentence.unicodeScalars.contains($0) }
}
