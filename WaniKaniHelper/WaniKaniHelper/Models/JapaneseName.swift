// Name data for the Name Practice feature, loaded from the bundled japanese_names.json.
//
// Readings come from JMnedict (EDRDG) cross-checked against published frequency rankings,
// so each entry carries the one reading a learner should actually know. Name readings are
// famously irregular, which is why nothing here is generated at runtime: 愛 alone has 52
// attested readings, so a composed name could never be quizzed with a single right answer.
import Foundation

struct NameSegment: Codable, Hashable {
    let kanji: String
    let reading: String
}

struct JapaneseName: Codable, Hashable, Identifiable {
    let kanji: String
    let reading: String
    let romaji: String
    let type: String          // "surname" | "given"
    let gender: String?       // "m" | "f", given names only
    let rank: Int
    /// Per-kanji breakdown of the reading. Absent when the split couldn't be derived
    /// confidently (長谷川 はせがわ, for one) — better to show nothing than mislead.
    let segments: [NameSegment]?

    var id: String { type + kanji + reading }
    var isSurname: Bool { type == "surname" }
}
