// Foundation Models tool that lets Apple's models (on-device and Apple Cloud) look up vocabulary the
// learner has at Master or above, so example sentences are built from words they can already read.
// The model picks a topic for its sentence; the tool answers with known words related to that topic
// (matched on English meanings) topped up with a random mix, since meaning matches are sparse.
import Foundation
import Synchronization

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
nonisolated struct KnownVocabularyTool: Tool {
    let name = "findKnownWords"
    let description = "Returns Japanese words the learner already knows well, optionally related to a topic. Build the rest of your sentence from these words so the learner can read it."

    @Generable
    struct Arguments {
        @Guide(description: "A short English topic or scene for the sentence, such as food, school, weather or travel. Leave empty for any topic.")
        var topic: String
    }

    /// Snapshot taken on the main actor when the session is created; the tool itself runs off it.
    let words: [KnownWord]
    /// How many words one call returns. On-device keeps this small for its 8K context; the cloud
    /// model gets far more (see AppleFoundationBackend).
    let limit: Int
    /// Meanings help the small on-device model pick words; the cloud model already knows them, so
    /// leaving them out roughly halves the tokens per word.
    let includeMeanings: Bool

    /// Calls since the last reset — lets the Prompt Test screen report whether models use the tool.
    private static let callCount = Mutex(0)

    static var callsSinceReset: Int { callCount.withLock { $0 } }
    static func resetCallCount() { callCount.withLock { $0 = 0 } }

    func call(arguments: Arguments) async throws -> String {
        Self.callCount.withLock { $0 += 1 }

        let topic = arguments.topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let related = topic.isEmpty ? [] : words.filter { word in
            word.meanings.contains { $0.lowercased().contains(topic) }
        }

        var seen = Set<String>()
        let picks = (related.shuffled() + words.shuffled())
            .filter { seen.insert($0.characters).inserted }
            .prefix(limit)

        guard !picks.isEmpty else { return "The learner doesn't know any words well yet. Keep the sentence very simple." }
        if includeMeanings {
            return picks.map { "\($0.characters) (\($0.meanings.first ?? ""))" }.joined(separator: ", ")
        }
        return picks.map(\.characters).joined(separator: "、")
    }
}
#endif
