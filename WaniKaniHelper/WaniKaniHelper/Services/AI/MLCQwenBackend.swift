// AIBackend implementation using Qwen2.5-3B-Instruct-4bit via the MLXLLM framework.
// Downloads ~1.8 GB on first use to Library/Caches via defaultHubApi, then loads from cache on relaunch.
// Calls GPU.clearCache() after each inference to prevent Metal buffer accumulation crashes.
import Foundation
import Observation
import MLX
import MLXLLM
import MLXLMCommon

@Observable
@MainActor
final class QwenBackend: AIBackend {
    static let shared = QwenBackend()
    private init() {}

    // mlx-community 4-bit quantized build — ~1.7 GB download
    static let modelId = "mlx-community/Qwen2.5-3B-Instruct-4bit"

    private var container: ModelContainer?
    var isAvailable: Bool { container != nil }

    // defaultHubApi passes Library/Caches/ directly as downloadBase — no "huggingface" prefix.
    // localRepoLocation builds: cachesDir/models/{org}/{model}
    static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "models/\(modelId)")
    }

    static var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: cacheURL.path)
    }

    // Downloads the model if not cached, then loads it into memory.
    // progressHandler receives 0.0–1.0 across the combined download + init phase.
    func downloadAndLoad(progressHandler: @escaping (Double) -> Void) async throws {
        let config = ModelConfiguration(id: Self.modelId)
        container = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        ) { progress in
            Task { @MainActor in progressHandler(progress.fractionCompleted) }
        }
    }

    // Silent load on app relaunch — skips download, just loads from cache.
    func loadIfDownloaded() async {
        guard Self.isDownloaded, container == nil else { return }
        let config = ModelConfiguration(id: Self.modelId)
        container = try? await LLMModelFactory.shared.loadContainer(
            configuration: config
        ) { _ in }
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> AIGeneratedContent {
        guard let container else { throw AIBackendError.notAvailable }

        // Instruct the model to respond with plain JSON so we can parse structured output.
        let jsonSchema = """
        Respond ONLY with a valid JSON object — no markdown fences, no extra text before or after:
        {"japanese":"<sentence>"}
        """

        defer { GPU.clearCache() }

        let result = try await container.perform { context in
            let input = try await context.processor.prepare(
                input: UserInput(messages: [
                    ["role": "system", "content": systemPrompt + "\n\n" + jsonSchema],
                    ["role": "user",   "content": userPrompt]
                ])
            )
            return try MLXLMCommon.generate(
                input: input,
                parameters: GenerateParameters(maxTokens: 150, temperature: 0.7),
                context: context
            ) { (_: [Int]) -> GenerateDisposition in .more }
        }

        return try parseJSONResponse(result.output)
    }

    private func parseJSONResponse(_ raw: String) throws -> AIGeneratedContent {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.firstIndex(of: "{"),
              let end   = text.lastIndex(of: "}") else { throw AIBackendError.parseError }
        let jsonSlice = String(text[start...end])
        guard let data = jsonSlice.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw AIBackendError.parseError }
        return AIGeneratedContent(japanese: obj["japanese"] as? String ?? "")
    }
}
