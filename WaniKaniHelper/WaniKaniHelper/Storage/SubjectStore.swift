// SwiftData-backed store for all WaniKani subjects (radicals, kanji, vocabulary).
// Handles upserting subjects from the API, reading subjects by level or ID, tracking pass/burn state,
// syncing passed status from WaniKani assignments, and seeding from the bundled JSON on first launch.
import SwiftData
import Observation
import Foundation

@Observable
@MainActor
final class SubjectStore {
    private let context: ModelContext

    /// True while a subject sync is in flight, so the UI can show progress and avoid
    /// firing a second one.
    private(set) var isSyncing = false
    /// Message from the last failed sync, cleared on the next success.
    private(set) var syncError: String?

    /// When `subjects_bundle.json` was generated. Seeding records this — not the install date —
    /// as the sync baseline, so a fresh install still pulls everything WaniKani has changed
    /// since the bundle was built (levels get reshuffled, subjects get retired).
    /// Update this whenever the bundle is regenerated.
    static let bundleVintage: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 7
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }()

    /// Subject content changes rarely, so once a day is plenty.
    private static let syncInterval: TimeInterval = 60 * 60 * 24

    init(context: ModelContext) {
        self.context = context
        migrateSyncBaseline()
    }

    /// Installs from before subject syncing existed recorded the *install* date as their sync
    /// baseline, even though their data came from the bundle. Rewinding those to the bundle
    /// vintage once makes the first real sync pull everything they missed.
    private func migrateSyncBaseline() {
        let flag = "subjectSyncBaselineFixed"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        if let last = lastSyncDate, last > Self.bundleVintage {
            recordSync(at: Self.bundleVintage)
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("SubjectStore save failed: \(error)")
        }
    }

    // MARK: - Write

    func upsertSubjects(_ resources: [(id: Int, type: String, data: WKSubjectData)]) {
        for resource in resources {
            let id = resource.id
            let descriptor = FetchDescriptor<CachedSubject>(
                predicate: #Predicate { $0.id == id }
            )
            let existing = try? context.fetch(descriptor).first

            let meanings = resource.data.meanings
                .filter { $0.acceptedAnswer }
                .map { $0.meaning }

            let readings = resource.data.readings?
                .filter { $0.acceptedAnswer }
                .map { $0.reading } ?? []

            let componentIds = resource.data.componentSubjectIds ?? []

            let imageURL = resource.data.characterImageURL

            if let subject = existing {
                subject.type = resource.type
                subject.characters = resource.data.characters
                subject.slug = resource.data.slug
                subject.level = resource.data.level
                subject.meanings = meanings
                subject.readings = readings
                subject.meaningMnemonic = resource.data.meaningMnemonic
                subject.characterImageURL = imageURL
                subject.hiddenAt = resource.data.hiddenAt
                subject.componentSubjectIds = componentIds
                subject.updatedAt = Date()
            } else {
                let subject = CachedSubject(
                    id: id,
                    type: resource.type,
                    characters: resource.data.characters,
                    slug: resource.data.slug,
                    level: resource.data.level,
                    meanings: meanings,
                    readings: readings,
                    meaningMnemonic: resource.data.meaningMnemonic,
                    characterImageURL: imageURL,
                    hiddenAt: resource.data.hiddenAt,
                    updatedAt: Date(),
                    componentSubjectIds: componentIds
                )
                context.insert(subject)
            }
        }
        save()
    }

    // Upserts subjects fetched from the API (WKResource form) into the local cache. Used to
    // backfill subjects newer than the bundled snapshot so their lessons/reviews aren't dropped.
    func upsert(fetchedSubjects resources: [WKResource<WKSubjectData>]) {
        let mapped = resources.compactMap { r -> (id: Int, type: String, data: WKSubjectData)? in
            guard let id = r.id else { return nil }
            return (id: id, type: r.object, data: r.data)
        }
        upsertSubjects(mapped)
    }

    func applyPassedStatus(passedIds: Set<Int>) {
        let descriptor = FetchDescriptor<CachedSubject>()
        let all = (try? context.fetch(descriptor)) ?? []
        for subject in all {
            let shouldBePassed = passedIds.contains(subject.id)
            if subject.isPassed != shouldBePassed {
                subject.isPassed = shouldBePassed
            }
        }
        save()
    }

    func markPassed(subjectId: Int) {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.id == subjectId }
        )
        if let subject = try? context.fetch(descriptor).first {
            subject.isPassed = true
            subject.lastReviewedAt = Date()
            save()
        }
    }

    func markBurned(subjectId: Int) {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.id == subjectId }
        )
        if let subject = try? context.fetch(descriptor).first {
            subject.isPassed = true
            subject.isBurned = true
            subject.lastReviewedAt = Date()
            save()
        }
    }

    // MARK: - Read

    func subjectMap(ids: [Int]) -> [Int: CachedSubject] {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let subjects = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
    }

    func vocabularyContaining(kanjiId: Int, limit: Int = 3) -> [CachedSubject] {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.type == "vocabulary" }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return Array(all.filter { $0.componentSubjectIds.contains(kanjiId) }.prefix(limit))
    }

    func kanjiInSentence(_ sentence: String) -> [CachedSubject] {
        let chars = sentence.unicodeScalars
            .filter {
                ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
                ($0.value >= 0x3400 && $0.value <= 0x4DBF)
            }
            .map { String($0) }
        let unique = Array(NSOrderedSet(array: chars)) as! [String]
        guard !unique.isEmpty else { return [] }
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.type == "kanji" }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let byChar = Dictionary(uniqueKeysWithValues: all.compactMap { s -> (String, CachedSubject)? in
            guard let c = s.characters else { return nil }
            return (c, s)
        })
        return unique.compactMap { byChar[$0] }
    }

    func components(for subject: CachedSubject) -> [CachedSubject] {
        let ids = subject.componentSubjectIds
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func distractorMeanings(excluding subjectId: Int, count: Int) -> [String] {
        var descriptor = FetchDescriptor<CachedSubject>()
        descriptor.fetchLimit = 60
        let subjects = (try? context.fetch(descriptor)) ?? []
        return subjects
            .filter { $0.id != subjectId && !$0.meanings.isEmpty }
            .shuffled()
            .prefix(count)
            .compactMap { $0.meanings.first }
    }

    func distractorReadings(excluding subjectId: Int, count: Int) -> [String] {
        var descriptor = FetchDescriptor<CachedSubject>()
        descriptor.fetchLimit = 60
        let subjects = (try? context.fetch(descriptor)) ?? []
        return subjects
            .filter { $0.id != subjectId && !$0.readings.isEmpty }
            .shuffled()
            .prefix(count)
            .compactMap { $0.readings.first }
    }

    var totalCached: Int {
        let descriptor = FetchDescriptor<CachedSubject>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func subjects(level: Int) -> [CachedSubject] {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.level == level }
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.hiddenAt == nil }
    }

    func subjectTotals(level: Int) -> (radicalTotal: Int, kanjiTotal: Int, vocabTotal: Int) {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.level == level }
        )
        let subjects = ((try? context.fetch(descriptor)) ?? []).filter { $0.hiddenAt == nil }
        return (
            subjects.filter { $0.subjectType == .radical }.count,
            subjects.filter { $0.subjectType == .kanji }.count,
            subjects.filter { $0.subjectType.isVocab }.count
        )
    }

    func subjectIds(level: Int) -> [Int] {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.level == level }
        )
        let subjects = ((try? context.fetch(descriptor)) ?? []).filter { $0.hiddenAt == nil }
        return subjects.map { $0.id }
    }

    // MARK: - Lock Screen widget

    /// Learned vocabulary (passed, not hidden) mapped to lightweight widget words,
    /// shuffled and capped so the shared file stays small.
    func passedVocabularyWords(limit: Int = 200) -> [WidgetWord] {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate {
                ($0.type == "vocabulary" || $0.type == "kana_vocabulary")
                    && $0.isPassed && $0.hiddenAt == nil
            }
        )
        let subjects = (try? context.fetch(descriptor)) ?? []
        let words = subjects.compactMap { WidgetWord(subject: $0) }
        return Array(words.shuffled().prefix(limit))
    }

    /// Early-level vocabulary for users who haven't passed anything yet, so the
    /// widget is never blank on a fresh install.
    func fallbackVocabularyWords(limit: Int = 60) -> [WidgetWord] {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate {
                ($0.type == "vocabulary" || $0.type == "kana_vocabulary")
                    && $0.hiddenAt == nil && $0.level <= 3
            }
        )
        let subjects = (try? context.fetch(descriptor)) ?? []
        let words = subjects.compactMap { WidgetWord(subject: $0) }
        return Array(words.shuffled().prefix(limit))
    }

    func levelProgress(for level: Int) -> (passed: Int, total: Int) {
        let descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.level == level && $0.type == "kanji" }
        )
        let kanji = ((try? context.fetch(descriptor)) ?? []).filter { $0.hiddenAt == nil }
        return (kanji.filter { $0.isPassed }.count, kanji.count)
    }

    func allKanjiByLevel() -> [(level: Int, kanji: [CachedSubject])] {
        var descriptor = FetchDescriptor<CachedSubject>(
            predicate: #Predicate { $0.type == "kanji" },
            sortBy: [SortDescriptor(\.level), SortDescriptor(\.id)]
        )
        descriptor.propertiesToFetch = [\.id, \.type, \.characters, \.slug, \.level, \.isPassed, \.hiddenAt]
        let all = ((try? context.fetch(descriptor)) ?? []).filter { $0.hiddenAt == nil }
        let grouped = Dictionary(grouping: all) { $0.level }
        return grouped.keys.sorted().map { level in
            (level: level, kanji: grouped[level]!.sorted { $0.id < $1.id })
        }
    }

    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: "subjectLastSync") as? Date
    }

    func recordSync(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: "subjectLastSync")
    }

    /// True when no sync has happened yet, or the last one is older than `syncInterval`.
    var needsSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > Self.syncInterval
    }

    // MARK: - Subject sync

    /// Pulls subjects changed since the last sync and upserts them, which is what keeps each
    /// subject's `level` current — WaniKani moves kanji and vocabulary between levels, and
    /// without this the bundled levels would be frozen at the vintage above forever.
    /// Incremental by default, so on most days this is a single small page.
    func syncSubjects(force: Bool = false) async {
        guard !isSyncing else { return }
        guard force || needsSync else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let updated = try await WaniKaniAPIClient.shared.fetchAllSubjects(updatedAfter: lastSyncDate)
            if !updated.isEmpty {
                upsert(fetchedSubjects: updated)
            }
            recordSync()
            syncError = nil
        } catch {
            // Offline or rate-limited: keep the old baseline so the next attempt retries the
            // same window rather than skipping changes.
            syncError = error.localizedDescription
        }
    }

    // MARK: - Bundle import / export

    /// Loads subjects_bundle.json from the app bundle and seeds the store.
    /// No-op if the store already has subjects or the file doesn't exist.
    func importFromBundle() {
        guard totalCached == 0 else { return }
        guard let url = Bundle.main.url(forResource: "subjects_bundle", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let subjects = try? JSONDecoder().decode([BundledSubject].self, from: data),
              !subjects.isEmpty else { return }

        for s in subjects {
            context.insert(CachedSubject(
                id: s.id,
                type: s.type,
                characters: s.characters,
                slug: s.slug,
                level: s.level,
                meanings: s.meanings,
                readings: s.readings,
                meaningMnemonic: s.meaningMnemonic,
                characterImageURL: s.characterImageURL,
                hiddenAt: nil,
                updatedAt: Date(),
                componentSubjectIds: s.componentSubjectIds
            ))
        }
        save()
        recordSync(at: Self.bundleVintage)
    }
}
