// SRS-stage groupings used by the Kanji Review practice feature. Each category maps to the
// WaniKani SRS stage range it covers. Stage 0 (in lessons, not yet started) belongs to no
// category and is excluded from practice.
import Foundation

enum KanjiCategory: String, CaseIterable, Identifiable {
    case apprentice
    case guru
    case master
    case enlightened
    case burned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apprentice:  return "Apprentice"
        case .guru:        return "Guru"
        case .master:      return "Master"
        case .enlightened: return "Enlightened"
        case .burned:      return "Burned"
        }
    }

    // WaniKani SRS stages: Apprentice 1–4, Guru 5–6, Master 7, Enlightened 8, Burned 9.
    var stages: ClosedRange<Int> {
        switch self {
        case .apprentice:  return 1...4
        case .guru:        return 5...6
        case .master:      return 7...7
        case .enlightened: return 8...8
        case .burned:      return 9...9
        }
    }

    func contains(srsStage: Int) -> Bool { stages.contains(srsStage) }

    static func category(for srsStage: Int) -> KanjiCategory? {
        allCases.first { $0.contains(srsStage: srsStage) }
    }
}
