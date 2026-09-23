// "Known" kanji for example sentences: kanji the user currently has at Master or above, plus the
// target word's own kanji. Sentence generators use this to prefer sentences the user can actually
// read (best-effort — they keep the attempt with the fewest unknown kanji), and the sentence cards
// use it to highlight the unknown ones so they can be tapped.
import Foundation
import SwiftData

@MainActor
enum KnownKanji {
    /// Extra attempts allowed after the first usable sentence, hunting for fewer unknown kanji.
    /// Shared by `bestKnownKanjiSentence` and the Prompt Test screen so they measure the same thing.
    nonisolated static let improvementTries = 2

    private static var cached: Set<Character>?

    static var all: Set<Character> {
        if let cached { return cached }
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.type == "kanji" && $0.isMastered }
        )
        let found = (try? WaniKaniHelperApp.modelContainer.mainContext.fetch(descriptor)) ?? []
        let set = Set(found.compactMap { $0.characters?.first })
        cached = set
        return set
    }

    private static var cachedVocabulary: [KnownWord]?

    /// Vocabulary at Master or above — what KnownVocabularyTool hands the model to build sentences
    /// from. Same "known" rule as the kanji set.
    static var vocabulary: [KnownWord] {
        if let cachedVocabulary { return cachedVocabulary }
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.type == "vocabulary" && $0.isMastered }
        )
        let found = (try? WaniKaniHelperApp.modelContainer.mainContext.fetch(descriptor)) ?? []
        let words = found.compactMap { s -> KnownWord? in
            guard let chars = s.characters else { return nil }
            return KnownWord(characters: chars, meanings: s.meanings)
        }
        cachedVocabulary = words
        return words
    }

    /// Called after SRS status sync changes which items are mastered.
    static func invalidate() {
        cached = nil
        cachedVocabulary = nil
    }

    /// Kanji in `sentence` the user doesn't know yet, in order of first appearance. The target
    /// word's kanji always count as known — the sentence exists to teach that word.
    static func unknown(in sentence: String, target: String) -> [Character] {
        let allowed = all.union(target.filter(\.isKanji))
        var seen = Set<Character>()
        return sentence.filter { $0.isKanji && !allowed.contains($0) && seen.insert($0).inserted }
            .map { $0 }
    }
}

/// Plain snapshot of a known vocabulary word, safe to hand to a tool running off the main actor.
nonisolated struct KnownWord: Sendable {
    let characters: String
    let meanings: [String]
}

extension Character {
    /// CJK Unified Ideographs and Extension A — the same ranges `sentenceContainsWord` checks.
    var isKanji: Bool {
        guard unicodeScalars.count == 1, let v = unicodeScalars.first?.value else { return false }
        return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v)
    }
}

/// Runs `attempt` up to `maxAttempts` times and returns the sentence that contains `target` with
/// the fewest unknown kanji. Returns immediately on a sentence with none. Once a usable sentence
/// exists it only tries `improvementTries` more times, so low-level users — for whom almost every
/// sentence has an unknown kanji — aren't always made to wait for every attempt.
@MainActor
func bestKnownKanjiSentence(
    target: String,
    maxAttempts: Int,
    improvementTries: Int = KnownKanji.improvementTries,
    attempt: () async throws -> AIGeneratedContent
) async -> AIGeneratedContent? {
    var best: (content: AIGeneratedContent, unknown: Int)?
    var triesSinceBest = 0

    for _ in 0..<maxAttempts {
        if let result = try? await attempt(), sentenceContainsWord(target, in: result.japanese) {
            let unknown = KnownKanji.unknown(in: result.japanese, target: target).count
            if unknown == 0 { return result }
            if best == nil || unknown < best!.unknown { best = (result, unknown) }
        }
        if best != nil {
            triesSinceBest += 1
            if triesSinceBest > improvementTries { break }
        }
    }
    return best?.content
}
