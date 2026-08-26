// Writable overlay for example sentences generated on-device by Claude.
// The bundled wanikani_vocab_sentences.json lives inside the (read-only) app bundle, so newly
// generated sentences can't be appended there. Instead they're persisted here in Application
// Support and merged into the pre-generated pool at read time (see BundledSentenceStore).
// Keyed by WaniKani subject ID.
import Foundation

@MainActor
final class SavedSentenceStore {
    static let shared = SavedSentenceStore()

    private var sentenceMap: [Int: [String]] = [:]
    private let fileURL: URL

    var isAvailable: Bool { !sentenceMap.isEmpty }

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("saved_sentences.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? JSONDecoder().decode([Int: [String]].self, from: data) else { return }
        sentenceMap = map
    }

    func sentences(for subjectId: Int) -> [String] {
        sentenceMap[subjectId] ?? []
    }

    func randomSentence(for subjectId: Int) -> String? {
        sentenceMap[subjectId]?.randomElement()
    }

    // Appends a generated sentence for a subject (skipping duplicates) and persists to disk.
    func append(_ sentence: String, for subjectId: Int) {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = sentenceMap[subjectId] ?? []
        guard !list.contains(trimmed) else { return }
        list.append(trimmed)
        sentenceMap[subjectId] = list
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(sentenceMap)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[SavedSentenceStore] persist failed: \(error)")
        }
    }
}
