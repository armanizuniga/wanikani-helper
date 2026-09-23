// Kanji and vocabulary as App Entities, so Siri, Spotlight and Shortcuts can find and refer to
// them ("Look up 勉強"). Only items at or below the user's current level are exposed, so search
// never surfaces material from levels they haven't reached. Radicals are left out — many have no
// characters and no reading, and they aren't what people look up.
import AppIntents
import CoreSpotlight
import SwiftData

nonisolated struct SubjectEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "WaniKani Item",
        numericFormat: "\(placeholder: .int) WaniKani items"
    )
    static let defaultQuery = SubjectEntityQuery()

    let id: Int
    let characters: String
    let meanings: [String]
    let readings: [String]
    let level: Int
    let typeLabel: String   // "Kanji", "Vocabulary"

    var meaning: String { meanings.first ?? "" }
    var reading: String? { readings.first }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = [meaning, reading].compactMap { $0 }.joined(separator: " · ")
        return DisplayRepresentation(title: "\(characters)", subtitle: "\(subtitle)")
    }

    // Spotlight matches on keywords, so every accepted meaning and reading is searchable —
    // "study", "べんきょう" and "勉強" all find the same item.
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet()
        set.displayName = characters
        set.title = characters
        set.contentDescription = "\(meanings.joined(separator: ", ")) · \(readings.joined(separator: ", ")) · Level \(level) \(typeLabel.lowercased())"
        set.keywords = [characters] + meanings + readings
        return set
    }
}

extension SubjectEntity {
    init(_ subject: CachedSubject) {
        self.init(
            id: subject.id,
            characters: subject.characters ?? subject.slug ?? "?",
            meanings: subject.meanings,
            readings: subject.readings,
            level: subject.level,
            typeLabel: subject.subjectType == .kanji ? "Kanji" : "Vocabulary"
        )
    }
}

// MARK: - Query

nonisolated struct SubjectEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [Int]) async throws -> [SubjectEntity] {
        let ids = identifiers
        let descriptor = FetchDescriptor<CachedSubject>(predicate: #Predicate { ids.contains($0.id) })
        let found = (try? SubjectLookup.context.fetch(descriptor)) ?? []
        return found.map(SubjectEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [SubjectEntity] {
        SubjectLookup.search(string).map(SubjectEntity.init)
    }

    // Shown when the user picks an item in Shortcuts without typing: their current level.
    @MainActor
    func suggestedEntities() async throws -> [SubjectEntity] {
        let level = WKUserData.cachedLevel
        return SubjectLookup.unlocked()
            .filter { $0.level == level }
            .map(SubjectEntity.init)
    }
}

// MARK: - Lookup helpers

@MainActor
enum SubjectLookup {
    static var context: ModelContext { WaniKaniHelperApp.modelContainer.mainContext }

    /// Kanji and vocabulary at or below the user's level, excluding subjects WaniKani retired.
    static func unlocked() -> [CachedSubject] {
        let level = max(WKUserData.cachedLevel, 1)
        let descriptor = FetchDescriptor<CachedSubject>(predicate: #Predicate { $0.level <= level })
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.hiddenAt == nil && $0.subjectType != .radical && $0.characters != nil
        }
    }

    /// Matches Japanese text (characters or reading) or an English meaning. Exact matches rank
    /// first, then prefix matches, then anything containing the query.
    static func search(_ query: String, limit: Int = 20) -> [CachedSubject] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var scored: [(CachedSubject, Int)] = []
        for subject in unlocked() {
            let chars = subject.characters ?? ""
            let terms = [chars] + subject.readings + subject.meanings.map { $0.lowercased() }
            if terms.contains(q) {
                scored.append((subject, 0))
            } else if terms.contains(where: { $0.hasPrefix(q) }) {
                scored.append((subject, 1))
            } else if terms.contains(where: { $0.contains(q) }) {
                scored.append((subject, 2))
            }
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.level < $1.0.level }
            .prefix(limit)
            .map(\.0)
    }
}

/// One component shown in the Explain snippet — a kanji inside a word, or a radical inside a kanji.
struct SubjectPart {
    let characters: String
    let meaning: String
    let type: SubjectType
}

extension SubjectLookup {
    struct Example {
        let japanese: String
        let english: String?
    }

    static func subject(id: Int) -> CachedSubject? {
        let descriptor = FetchDescriptor<CachedSubject>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    /// Component subjects that have printable characters (image-only radicals are skipped).
    static func components(of subject: CachedSubject) -> [SubjectPart] {
        let ids = subject.componentSubjectIds
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<CachedSubject>(predicate: #Predicate { ids.contains($0.id) })
        let found = (try? context.fetch(descriptor)) ?? []
        return ids.compactMap { id in
            guard let c = found.first(where: { $0.id == id }), let chars = c.characters else { return nil }
            return SubjectPart(characters: chars, meaning: c.meanings.first ?? "", type: c.subjectType)
        }
    }

    /// A bundled sentence with its English translation when there is one, otherwise any saved or
    /// bundled sentence (saved AI sentences have no translation).
    static func exampleSentence(for subjectId: Int) -> Example? {
        SentenceStore.shared.load()   // no-op once loaded; intents can run before the app has
        if let s = SentenceStore.shared.sentences(for: subjectId).randomElement() {
            return Example(japanese: s.japanese, english: s.english)
        }
        return BundledSentenceStore.shared.randomSentence(for: subjectId).map { Example(japanese: $0, english: nil) }
    }
}

// MARK: - Spotlight index

@MainActor
enum SubjectSpotlightIndex {
    private static let levelKey = "spotlightIndexedLevel"
    private static let dateKey  = "spotlightIndexedAt"

    /// Re-indexes when the user's level changes (new items unlocked) or once a week to pick up
    /// subject content changes. Cheap to call on every launch.
    static func refreshIfNeeded(level: Int) async {
        let defaults = UserDefaults.standard
        let lastLevel = defaults.integer(forKey: levelKey)
        let lastDate  = defaults.object(forKey: dateKey) as? Date ?? .distantPast
        guard level > 0,
              level != lastLevel || Date().timeIntervalSince(lastDate) > 60 * 60 * 24 * 7
        else { return }

        let entities = SubjectLookup.unlocked().map(SubjectEntity.init)
        do {
            let index = CSSearchableIndex.default()
            try await index.deleteAppEntities(ofType: SubjectEntity.self)
            try await index.indexAppEntities(entities)
            defaults.set(level, forKey: levelKey)
            defaults.set(Date(), forKey: dateKey)
        } catch {
            print("[SubjectSpotlightIndex] indexing failed: \(error)")
        }
    }

    /// Removes every indexed item — used on sign out.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: levelKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
        Task {
            try? await CSSearchableIndex.default().deleteAppEntities(ofType: SubjectEntity.self)
        }
    }
}
