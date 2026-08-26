// SwiftData model representing a single hiragana or katakana character in the kana SRS system.
// Tracks mastery level (0–5), consecutive correct answers, and historical correct/incorrect counts
// to drive the weighted review queue in KanaSRSStore.
import SwiftData
import Foundation

@Model
final class KanaSRSEntry {
    @Attribute(.unique) var character: String
    var script: String           // "hiragana" | "katakana"
    var masteryLevel: Int        // 0–5
    var consecutiveCorrect: Int  // resets on wrong answer
    var totalCorrect: Int
    var totalIncorrect: Int
    var lastPracticed: Date?

    init(character: String, script: String) {
        self.character = character
        self.script = script
        self.masteryLevel = 0
        self.consecutiveCorrect = 0
        self.totalCorrect = 0
        self.totalIncorrect = 0
        self.lastPracticed = nil
    }
}
