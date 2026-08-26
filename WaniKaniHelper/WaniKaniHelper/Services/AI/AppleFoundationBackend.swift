// AIBackend implementation using Apple's FoundationModels framework (iOS 26+).
// Uses @Generable structured output to guarantee the model returns valid JSON with a japanese field.
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
private struct FoundationModelOutput {
    @Guide(description: "Japanese text only.")
    var japanese: String
}

@available(iOS 26.0, *)
final class AppleFoundationBackend: AIBackend {
    static let shared = AppleFoundationBackend()
    private init() {}

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func generate(systemPrompt: String, userPrompt: String) async throws -> AIGeneratedContent {
        var session: LanguageModelSession? = LanguageModelSession(instructions: systemPrompt)
        defer { session = nil }
        do {
            let response = try await session!.respond(to: userPrompt, generating: FoundationModelOutput.self)
            return AIGeneratedContent(japanese: response.content.japanese)
        } catch {
            let data = session!.logFeedbackAttachment(
                sentiment: .negative,
                issues: [.init(category: .triggeredGuardrailUnexpectedly)],
                desiredResponseText: nil
            )
            if let json = String(data: data, encoding: .utf8) {
                print("[AppleFoundationBackend] Feedback attachment:\n\(json)")
            }
            throw error
        }
    }
}
#endif
