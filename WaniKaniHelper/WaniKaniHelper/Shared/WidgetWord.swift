// A single vocabulary word surfaced on the Lock Screen widget.
// Deliberately dependency-free (no SwiftData) so it can be shared between the app
// and the WaniWidget extension without pulling the whole model layer into the widget.
import Foundation

struct WidgetWord: Codable, Hashable {
    let characters: String   // the Japanese word, e.g. "食べ物"
    let reading: String      // kana reading, e.g. "たべもの" (may equal `characters` for kana vocab)
    let meaning: String      // primary English meaning, e.g. "food"
    let level: Int           // WaniKani level the word belongs to

    /// True when the reading adds nothing over the characters (kana-only vocab),
    /// so the widget can avoid printing the same text twice.
    var readingIsRedundant: Bool {
        reading.isEmpty || reading == characters
    }
}
