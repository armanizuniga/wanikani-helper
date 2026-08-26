// Shared protocol and types for on-device AI sentence generation.
// AIBackend is implemented by QwenBackend (MLX) and AppleFoundationBackend (iOS 26+).
// AIGeneratedContent holds the single output field: a plain Japanese sentence.
import Foundation

struct AIGeneratedContent {
    var japanese: String
}

enum AIBackendError: Error {
    case notAvailable
    case parseError
}

protocol AIBackend: AnyObject {
    var isAvailable: Bool { get }
    func generate(systemPrompt: String, userPrompt: String) async throws -> AIGeneratedContent
}
