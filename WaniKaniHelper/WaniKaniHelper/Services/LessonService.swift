// Manages the state of a lesson session. Fetches pending lesson assignments from the WaniKani API,
// orders them by level then type (radicals → kanji → vocabulary), and steps through them one at a time.
// Calls the WaniKani API to start each assignment when the user advances past it.
import Foundation
import Observation

struct LessonItem: Identifiable {
    let id: Int
    let assignmentId: Int
    let subjectId: Int
    let subject: CachedSubject
}

@Observable
@MainActor
final class LessonService {
    private(set) var queue: [LessonItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isLoading = false
    private(set) var sessionComplete = false
    private(set) var error: String?

    private let api = WaniKaniAPIClient.shared
    private let store: SubjectStore

    init(store: SubjectStore) {
        self.store = store
    }

    var current: LessonItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var totalCount: Int { queue.count }

    var isOnLastItem: Bool {
        !queue.isEmpty && currentIndex == queue.count - 1
    }

    func loadQueue() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let assignments = try await api.fetchLessonAssignments()
            let subjectIds = assignments.map { $0.data.subjectId }
            var subjectMap = store.subjectMap(ids: subjectIds)

            // Backfill any lesson subjects newer than the bundled snapshot, otherwise they'd be
            // silently dropped below and never appear as lessons.
            let missingIds = subjectIds.filter { subjectMap[$0] == nil }
            if !missingIds.isEmpty, let fetched = try? await api.fetchSubjects(ids: missingIds), !fetched.isEmpty {
                store.upsert(fetchedSubjects: fetched)
                subjectMap = store.subjectMap(ids: subjectIds)
            }

            func typePriority(_ type: SubjectType?) -> Int {
                switch type {
                case .radical: return 0
                case .kanji:   return 1
                default:       return 2
                }
            }

            queue = assignments
                .sorted {
                    let levelDiff = $0.data.level - $1.data.level
                    if levelDiff != 0 { return levelDiff < 0 }
                    let typeDiff = typePriority($0.data.subjectTypeEnum) - typePriority($1.data.subjectTypeEnum)
                    if typeDiff != 0 { return typeDiff < 0 }
                    return $0.data.subjectId < $1.data.subjectId
                }
                .compactMap { assignment in
                    guard let subject = subjectMap[assignment.data.subjectId],
                          let id = assignment.id else { return nil }
                    return LessonItem(id: id, assignmentId: id, subjectId: assignment.data.subjectId, subject: subject)
                }
            currentIndex = 0
            sessionComplete = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func advance() {
        guard currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        Task { try? await api.startAssignment(id: item.assignmentId) }

        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else {
            sessionComplete = true
        }
    }
}
