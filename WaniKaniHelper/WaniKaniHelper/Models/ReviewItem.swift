// In-memory model for a single review question shown during a review session.
// Each WaniKani assignment generates two ReviewItems — one for meaning, one for reading.
// Holds the multiple-choice options, the correct answer, the user's selection, and whether
// the item has been answered.
import Foundation

enum QuestionType {
    case meaning
    case reading
}

struct ReviewItem: Identifiable {
    let id: Int           // assignmentId * 2 for meaning, +1 for reading
    let assignmentId: Int
    let subjectId: Int
    let subject: CachedSubject
    let questionType: QuestionType

    var choices: [String] = []
    var correctChoice: String = ""
    var selectedChoice: String? = nil
    var answered: Bool = false
    var incorrectCount: Int = 0

    var choiceWasCorrect: Bool? {
        guard let selected = selectedChoice else { return nil }
        return selected == correctChoice
    }
}
