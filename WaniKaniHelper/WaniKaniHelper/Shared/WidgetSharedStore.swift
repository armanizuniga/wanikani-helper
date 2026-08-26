// Read/write bridge for the small list of words the Lock Screen widget displays.
// The app writes the list into the shared App Group container; the WaniWidget
// extension reads it back. Shared by both targets — keep it dependency-free.
import Foundation

enum WidgetShared {
    /// Must match the App Group capability enabled on BOTH the app and widget targets.
    static let appGroupID = "group.ArmaniZuniga.WaniKaniHelper"
    static let fileName = "widget_words.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    static func save(_ words: [WidgetWord]) {
        guard let url = fileURL else {
            print("WidgetShared: no App Group container — is the capability enabled?")
            return
        }
        do {
            let data = try JSONEncoder().encode(words)
            try data.write(to: url, options: .atomic)
        } catch {
            print("WidgetShared save failed: \(error)")
        }
    }

    static func load() -> [WidgetWord] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WidgetWord].self, from: data)) ?? []
    }
}
