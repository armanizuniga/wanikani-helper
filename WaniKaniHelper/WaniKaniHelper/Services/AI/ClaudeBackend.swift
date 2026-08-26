// AIBackend implementation backed by the Claude API (cloud).
// Opt-in / bring-your-own-key: the user pastes their own Anthropic API key, stored in the
// Keychain. Swift has no official Anthropic SDK, so this talks to the Messages API over
// raw HTTP with URLSession. Sentences are tiny single-shot completions — no streaming needed.
import Foundation

final class ClaudeBackend: AIBackend {
    static let shared = ClaudeBackend()
    private init() {}

    // Separate Keychain account from the WaniKani token.
    static let keychainAccount = "anthropicKey"
    private let model = "claude-haiku-4-5"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static var apiKey: String? {
        let key = KeychainService.load(account: keychainAccount)
        return (key?.isEmpty == false) ? key : nil
    }

    static func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainService.delete(account: keychainAccount)
        } else {
            KeychainService.save(trimmed, account: keychainAccount)
        }
    }

    static func deleteKey() { KeychainService.delete(account: keychainAccount) }

    var isAvailable: Bool { Self.apiKey != nil }

    // MARK: - Dedicated sentence generation (Claude-only path)

    // Builds a richer prompt than the on-device backends can handle: the full list of 135 grammar
    // points (Claude chooses the most natural one), the learner's WaniKani level (Claude picks
    // level-appropriate vocab), and a hard "one sentence only" constraint.
    // Used by SentenceGeneratorService and ExampleGeneratorService when Claude is active.
    func generateSentence(
        targetWord: String,
        reading: String?,
        meaning: String,
        userLevel: Int,
        avoiding: [String] = []
    ) async throws -> AIGeneratedContent {
        let systemPrompt = Self.sentenceSystemPrompt(
            word: targetWord, reading: reading, meaning: meaning, userLevel: userLevel, avoiding: avoiding
        )
        let userPrompt = "Write one natural Japanese sentence using \(targetWord)."
        let raw = try await generate(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return AIGeneratedContent(japanese: Self.firstSentence(raw.japanese))
    }

    // Lists all grammar points for Claude to choose from, states the learner's level so Claude
    // can judge appropriate vocabulary, and enforces strict single-sentence output.
    private static func sentenceSystemPrompt(
        word: String, reading: String?, meaning: String, userLevel: Int, avoiding: [String] = []
    ) -> String {
        var prompt = """
        You are a Japanese tutor writing ONE natural example sentence for a vocabulary learner.

        Target word: \(word)（\(meaning)）

        From the grammar points below, choose the SINGLE one that makes the most natural, everyday \
        sentence with this word. Don't force a complex pattern — pick what a native speaker would \
        actually say.

        Grammar points:
        \(PromptLibrary.grammarPointsList)
        """

        prompt += """


        Style:
        - Set the sentence in a concrete, everyday situation a learner would actually meet — home, \
        work, school, shopping, travel, food, friends. Avoid abstract, obscure, or \
        proper-noun-heavy sentences.
        - Pick a fresh, slightly unexpected everyday scene rather than the most obvious one, and \
        vary the setting, people, and action so repeated requests produce genuinely different \
        sentences — not small variations on the same idea.
        """

        if userLevel > 0 {
            prompt += """


            The learner is at WaniKani level \(userLevel) of 60. Choose vocabulary and kanji they are \
            likely to know at that level, but natural Japanese comes first — if a native speaker \
            would naturally use a simpler or more advanced word, that's fine.
            """
        }

        if !avoiding.isEmpty {
            let list = avoiding.map { "- \($0)" }.joined(separator: "\n")
            prompt += """


            You have already written these sentences for this word. Make the new one clearly \
            different — choose a DIFFERENT grammar point and a different scene, situation, and \
            wording from every one of them:
            \(list)
            """
        }

        prompt += """


        Output rules (strict):
        - Reply with EXACTLY ONE Japanese sentence and nothing else.
        - No English, no translation, no explanation, no quotation marks, no furigana, no romaji.
        - The sentence must contain \(word) in some natural form.
        - End with whichever single mark is most natural — 。, ？, or ！ (a question or exclamation \
        is fine when it fits the scene).
        """
        return prompt
    }

    // Guarantees a single sentence even if the model returns more than one.
    private static func firstSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let end = trimmed.firstIndex(where: { "。！？".contains($0) }) {
            return String(trimmed[...end])
        }
        return trimmed
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> AIGeneratedContent {
        let text = try await complete(systemPrompt: systemPrompt, userPrompt: userPrompt, maxTokens: 256)
        return AIGeneratedContent(japanese: text)
    }

    // MARK: - Grammar explanation (Claude-only)

    // Takes a generated Japanese sentence and returns an English breakdown: a natural translation
    // plus a short explanation of the key grammar and vocabulary. Used by the inline example card's
    // "Explain grammar" button. Allows more tokens than sentence generation since the output is prose.
    func explainSentence(_ sentence: String) async throws -> String {
        let systemPrompt = """
        You are a Japanese tutor explaining a sentence to an English-speaking learner.
        Given one Japanese sentence, reply with:
        1. A natural English translation.
        2. A short breakdown of the key grammar points and vocabulary, in plain English.
        3. For any conjugated verb or adjective, explain how it is conjugated — name the dictionary \
        form and the steps used to reach the form in the sentence (e.g. polite -masu, past -ta, \
        te-form, negative, potential, conditional).
        Use romaji generously: give the romaji reading alongside Japanese words and grammar terms so \
        the learner can follow the pronunciation. Keep it concise and friendly. Write your \
        explanations in English. Do not repeat the sentence verbatim at the start.
        """
        let userPrompt = "Explain this Japanese sentence:\n\(sentence)"
        return try await complete(systemPrompt: systemPrompt, userPrompt: userPrompt, maxTokens: 1024)
    }

    // MARK: - Grammar chat (Claude-only)

    // A single turn in the follow-up conversation shown under a grammar explanation.
    struct ChatTurn {
        enum Role { case user, assistant }
        let role: Role
        let text: String
    }

    // Answers a follow-up question in the context of a previously explained sentence. `history`
    // starts with the assistant's original explanation; we prepend the implicit "explain this"
    // user turn so the Messages API sees a valid user/assistant alternation.
    func followUp(sentence: String, history: [ChatTurn]) async throws -> String {
        let systemPrompt = """
        You are a friendly Japanese tutor helping an English-speaking learner understand this sentence:
        \(sentence)
        Answer their follow-up questions about its grammar, vocabulary, nuance, or usage. When a verb \
        or adjective is conjugated, explain how — name the dictionary form and the steps used to reach \
        the form in question. Use romaji generously alongside Japanese words so the learner can follow \
        the pronunciation. Keep replies concise and clear, and write your explanations in English.
        """
        var messages: [RequestBody.Message] = [
            .init(role: "user", content: "Explain this Japanese sentence:\n\(sentence)")
        ]
        messages += history.map {
            .init(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        }
        return try await complete(systemPrompt: systemPrompt, messages: messages, maxTokens: 1024)
    }

    // MARK: - Shared request plumbing

    private func complete(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String {
        try await complete(
            systemPrompt: systemPrompt,
            messages: [.init(role: "user", content: userPrompt)],
            maxTokens: maxTokens
        )
    }

    private func complete(systemPrompt: String, messages: [RequestBody.Message], maxTokens: Int) async throws -> String {
        guard let key = Self.apiKey else { throw AIBackendError.notAvailable }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload = RequestBody(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            // 401 (bad key), 429 (rate limit), 5xx — surface as notAvailable so the caller's
            // retry/fallback loop handles it the same way as an on-device failure.
            throw AIBackendError.notAvailable
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIBackendError.parseError
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Wire format

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ResponseBody: Decodable {
        let content: [Block]

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }
}
