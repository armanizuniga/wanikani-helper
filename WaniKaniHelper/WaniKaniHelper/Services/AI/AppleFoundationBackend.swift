// AIBackend implementation using Apple's FoundationModels framework (iOS 26+).
// Uses @Generable structured output to guarantee the model returns valid JSON with a japanese field.
// Two instances: `shared` runs the on-device model; `cloud` runs Apple's larger Private Cloud
// Compute model (iOS 27+) and falls back to on-device when the cloud can't answer (offline,
// service down, or the app's free quota is used up).
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
private struct FoundationModelOutput {
    @Guide(description: "Japanese text only.")
    var japanese: String
}

@available(iOS 27.0, *)
enum AppleCloud {
    /// Private Cloud Compute needs the managed `com.apple.developer.private-cloud-compute`
    /// entitlement, which Apple grants on request
    /// (https://developer.apple.com/contact/request/private-cloud-compute/). Without it
    /// FoundationModels hits a fatalError — not a catchable error — on the first cloud call, so
    /// nothing may touch `model` unless this is true. Once Apple approves the request: add the
    /// entitlement to WaniKaniHelper.entitlements, then set this to true.
    static let isEntitled = false

    static let model = PrivateCloudComputeLanguageModel()

    /// Whether this device can use Private Cloud Compute at all — decides if the option is shown.
    static var isSupportedOnDevice: Bool {
        isEntitled && model.availability != .unavailable(.deviceNotEligible)
    }

    /// Whether a cloud request can be made right now.
    static var isReady: Bool {
        isEntitled && model.isAvailable
    }
}

@available(iOS 26.0, *)
final class AppleFoundationBackend: AIBackend {
    static let shared = AppleFoundationBackend(useCloud: false)
    static let cloud  = AppleFoundationBackend(useCloud: true)

    private let useCloud: Bool

    private init(useCloud: Bool) {
        self.useCloud = useCloud
    }

    /// Reason the last cloud request fell back to on-device, for the AI Model settings screen.
    /// Cleared on the next successful cloud response.
    private(set) var lastCloudFallbackReason: String?

    /// Words per known-words tool call on the on-device model — small, for its 8K context.
    static let onDeviceVocabLimit = 25
    /// Words per known-words tool call on Apple Cloud (32K context). 200 is a starting point;
    /// the Prompt Test screen compares 100 / 200 / 500.
    var cloudVocabLimit = 200
    /// Whether sessions get the known-words tool. Only the Prompt Test screen turns it off, to
    /// measure what the tool is worth.
    var toolEnabled = true

    var isAvailable: Bool {
        if useCloud {
            guard #available(iOS 27.0, *), AppleCloud.isEntitled else { return false }
            // The on-device fallback keeps the backend usable when the cloud model isn't ready.
            return AppleCloud.isReady || SystemLanguageModel.default.isAvailable
        }
        return SystemLanguageModel.default.isAvailable
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> AIGeneratedContent {
        if useCloud, #available(iOS 27.0, *), AppleCloud.isReady {
            do {
                let tools = knownWordsTools(cloud: true)
                // The cloud model's 32K context easily fits every kanji the learner knows, so it gets
                // the full list as well. The on-device model's 8K context doesn't have room to spare.
                let session = LanguageModelSession(
                    model: AppleCloud.model, tools: tools,
                    instructions: Self.instructions(systemPrompt, hasTool: !tools.isEmpty) + Self.knownKanjiInstruction()
                )
                let result = try await respond(session, to: userPrompt)
                lastCloudFallbackReason = nil
                return result
            } catch let error as PrivateCloudComputeLanguageModel.Error {
                // Network, outage or quota — none are the prompt's fault, so answer on-device instead.
                lastCloudFallbackReason = error.localizedDescription
                guard SystemLanguageModel.default.isAvailable else { throw error }
                print("[AppleFoundationBackend] Cloud unavailable, using on-device: \(error.debugDescription)")
            }
        }
        // On-device — either this is the on-device backend, or the cloud fell back. Either way the
        // tool is sized for the on-device context.
        let tools = knownWordsTools(cloud: false)
        let session = LanguageModelSession(tools: tools, instructions: Self.instructions(systemPrompt, hasTool: !tools.isEmpty))
        return try await respond(session, to: userPrompt)
    }

    // Known words come from a tool the model calls while writing; see KnownVocabularyTool. Skipped
    // when the learner has no Master vocabulary yet — an empty tool would just waste a round trip.
    private func knownWordsTools(cloud: Bool) -> [any Tool] {
        let words = KnownKanji.vocabulary
        guard toolEnabled, !words.isEmpty else { return [] }
        return [KnownVocabularyTool(
            words: words,
            limit: cloud ? cloudVocabLimit : Self.onDeviceVocabLimit,
            includeMeanings: !cloud
        )]
    }

    private static func instructions(_ systemPrompt: String, hasTool: Bool) -> String {
        guard hasTool else { return systemPrompt }
        return systemPrompt + " Before writing, call findKnownWords with a topic for your sentence, and build the rest of the sentence from the words it returns wherever that's natural."
    }

    private static func knownKanjiInstruction() -> String {
        let kanji = KnownKanji.all
        guard !kanji.isEmpty else { return "" }
        return " The learner can read these kanji: \(String(kanji.sorted())). Apart from the target word, write any word whose kanji aren't in that list in hiragana instead."
    }

    private func respond(_ session: LanguageModelSession, to userPrompt: String) async throws -> AIGeneratedContent {
        do {
            let response = try await session.respond(to: userPrompt, generating: FoundationModelOutput.self)
            return AIGeneratedContent(japanese: response.content.japanese)
        } catch {
            // Only guardrail blocks are worth a feedback report — a vocab sentence shouldn't trip
            // one. Network, quota, context-size and other errors aren't guardrail problems.
            if Self.isGuardrailViolation(error) {
                let data = session.logFeedbackAttachment(
                    sentiment: .negative,
                    issues: [.init(category: .triggeredGuardrailUnexpectedly)],
                    desiredResponseText: nil
                )
                if let json = String(data: data, encoding: .utf8) {
                    print("[AppleFoundationBackend] Guardrail feedback attachment:\n\(json)")
                }
            } else {
                print("[AppleFoundationBackend] Generation failed: \(error)")
            }
            throw error
        }
    }

    // iOS 27 reports guardrail blocks as LanguageModelError; iOS 26 used the now-deprecated
    // LanguageModelSession.GenerationError.
    private static func isGuardrailViolation(_ error: Error) -> Bool {
        if #available(iOS 27.0, *), let modelError = error as? LanguageModelError,
           case .guardrailViolation = modelError {
            return true
        }
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .guardrailViolation = generationError {
            return true
        }
        return false
    }
}
#endif
