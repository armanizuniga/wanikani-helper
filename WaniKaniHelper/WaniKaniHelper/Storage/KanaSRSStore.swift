// SwiftData-backed store for the kana SRS system. Seeds the database with all hiragana and
// katakana characters on first launch, provides weighted character selection that favors
// less-mastered characters, and updates mastery levels based on review performance.
import SwiftData
import Foundation

@Observable
@MainActor
final class KanaSRSStore {
    private let context: ModelContext

    // draw weights per mastery level (0–5)
    private let weights = [30, 15, 8, 3, 1, 1]

    init(context: ModelContext) {
        self.context = context
        seed()
    }

    // MARK: - Seeding

    private func seed() {
        guard (try? context.fetchCount(FetchDescriptor<KanaSRSEntry>())) == 0 else { return }
        for entry in KanaData.allHiragana {
            context.insert(KanaSRSEntry(character: entry.character, script: "hiragana"))
        }
        for entry in KanaData.allKatakana {
            context.insert(KanaSRSEntry(character: entry.character, script: "katakana"))
        }
        try? context.save()
    }

    // MARK: - Counts

    func masteredCount(script: String) -> Int {
        let s = script
        let descriptor = FetchDescriptor<KanaSRSEntry>(
            predicate: #Predicate { $0.script == s && $0.masteryLevel >= 5 }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func totalCount(script: String) -> Int {
        let s = script
        let descriptor = FetchDescriptor<KanaSRSEntry>(
            predicate: #Predicate { $0.script == s }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Selection (weighted random)

    func nextItem(script: String, excluding lastCharacter: String?) -> KanaSRSEntry? {
        let s = script
        let descriptor = FetchDescriptor<KanaSRSEntry>(
            predicate: #Predicate { $0.script == s }
        )
        var entries = (try? context.fetch(descriptor)) ?? []
        guard !entries.isEmpty else { return nil }

        // Avoid repeating the exact same character back-to-back
        if entries.count > 1, let last = lastCharacter {
            entries = entries.filter { $0.character != last }
        }

        let weighted: [(entry: KanaSRSEntry, weight: Int)] = entries.map { entry in
            (entry, weights[min(entry.masteryLevel, weights.count - 1)])
        }
        let total = weighted.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return entries.randomElement() }

        var roll = Int.random(in: 0..<total)
        for item in weighted {
            roll -= item.weight
            if roll < 0 { return item.entry }
        }
        return weighted.last?.entry
    }

    // MARK: - Mastery updates

    func recordCorrect(entry: KanaSRSEntry) {
        entry.consecutiveCorrect += 1
        entry.totalCorrect += 1
        entry.lastPracticed = Date()
        // Advance level when streak reaches the threshold for the current level
        // Level 0→1 needs 1 in a row; 1→2 needs 2; etc.
        let threshold = entry.masteryLevel + 1
        if entry.masteryLevel < 5 && entry.consecutiveCorrect >= threshold {
            entry.masteryLevel += 1
            entry.consecutiveCorrect = 0
        }
        try? context.save()
    }

    func recordIncorrect(entry: KanaSRSEntry) {
        entry.consecutiveCorrect = 0
        entry.totalIncorrect += 1
        entry.lastPracticed = Date()
        entry.masteryLevel = max(0, entry.masteryLevel - 2)
        try? context.save()
    }

    // MARK: - Helpers

    func romajiFor(character: String) -> [String] {
        KanaData.romaji(for: character)
    }

    func resetProgress(script: String) {
        let s = script
        let descriptor = FetchDescriptor<KanaSRSEntry>(
            predicate: #Predicate { $0.script == s }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        for e in entries {
            e.masteryLevel = 0
            e.consecutiveCorrect = 0
            e.totalCorrect = 0
            e.totalIncorrect = 0
            e.lastPracticed = nil
        }
        try? context.save()
    }
}
