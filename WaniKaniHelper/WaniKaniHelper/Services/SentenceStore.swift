// Static fallback store for pre-written vocabulary example sentences loaded from wanikani_vocab_sentences.json.
// Used on devices that do not support Apple's Foundation Models (below iOS 26) to display
// example sentences in lesson and review sessions instead of AI-generated ones.
import Foundation

struct ExampleSentence: Decodable {
    let japanese: String
    let english: String?
    let question: String?
    let questionEnglish: String?

    enum CodingKeys: String, CodingKey {
        case japanese = "sentence_ja"
        case english, question
        case questionEnglish = "question_english"
    }
}

struct VocabSentences: Decodable {
    let id: Int
    let sentences: [ExampleSentence]
}

final class SentenceStore {
    static let shared = SentenceStore()

    private var vocabMap: [Int: [ExampleSentence]] = [:]
    private var loaded = false

    private init() {}

    func load() {
        guard !loaded, let url = Bundle.main.url(forResource: "wanikani_vocab_sentences", withExtension: "json") else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        if let entries = try? JSONDecoder().decode([VocabSentences].self, from: data) {
            for entry in entries {
                vocabMap[entry.id] = entry.sentences
            }
        }
        loaded = true
    }

    func sentences(for subjectId: Int) -> [ExampleSentence] {
        vocabMap[subjectId] ?? []
    }
}
