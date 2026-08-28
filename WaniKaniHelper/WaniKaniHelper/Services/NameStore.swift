// Loads the bundled name list and hands out pools for the practice sessions.
import Foundation

@MainActor
final class NameStore {
    static let shared = NameStore()

    private(set) var surnames: [JapaneseName] = []
    private(set) var givenNames: [JapaneseName] = []

    var isAvailable: Bool { !surnames.isEmpty && !givenNames.isEmpty }

    private init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "japanese_names", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([JapaneseName].self, from: data)
        else { return }
        surnames = all.filter { $0.isSurname }.sorted { $0.rank < $1.rank }
        givenNames = all.filter { !$0.isSurname }.sorted { $0.rank < $1.rank }
    }
}
