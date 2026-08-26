// Loads wanikani_vocab_sentences.json from the app bundle — pre-generated example sentences
// indexed by WaniKani subject ID. Populated externally and bundled at build time.
import Foundation

final class BundledSentenceStore {
    static let shared = BundledSentenceStore()

    private var sentenceMap: [Int: [String]] = [:]
    // The bundled file is read-only; Claude-generated sentences are appended to a writable
    // overlay (SavedSentenceStore) and merged in here so the pre-generated pool grows over time.
    var isAvailable: Bool { !sentenceMap.isEmpty || SavedSentenceStore.shared.isAvailable }

    private init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "wanikani_vocab_sentences", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }

        struct Entry: Decodable {
            let id: Int
            let sentences: [Sentence]
            struct Sentence: Decodable {
                let sentence_ja: String
            }
        }

        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        sentenceMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.sentences.map { $0.sentence_ja }) })
    }

    func randomSentence(for subjectId: Int) -> String? {
        let bundled = sentenceMap[subjectId] ?? []
        let saved = SavedSentenceStore.shared.sentences(for: subjectId)
        return (bundled + saved).randomElement()
    }
}
