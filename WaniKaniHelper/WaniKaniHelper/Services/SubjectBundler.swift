// Defines the BundledSubject Codable model used to seed the local SwiftData store from
// subjects_bundle.json on first launch. Only stores accepted meanings and readings —
// no raw WaniKani API response data — to keep the bundle compact.
import Foundation

// Compact, pre-processed format used for the bundled subjects_bundle.json.
// Only accepted answers are stored — no raw API cruft.
struct BundledSubject: Codable {
    let id: Int
    let type: String
    let characters: String?
    let slug: String?
    let level: Int
    let meanings: [String]
    let readings: [String]
    let meaningMnemonic: String?
    let characterImageURL: String?
    let componentSubjectIds: [Int]
}
