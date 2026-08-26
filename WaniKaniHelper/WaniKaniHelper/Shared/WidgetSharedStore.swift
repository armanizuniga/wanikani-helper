// Read/write bridge for the small list of words the Lock Screen widget displays.
// The app writes the list into the shared App Group container; the WaniWidget
// extension reads it back. Shared by both targets — keep it dependency-free.
import Foundation

enum WidgetShared {
    static let fileName = "widget_words.json"

    /// App Group used when the bundle identifier convention below doesn't resolve. Only relevant
    /// to the original project; a fork gets its group from its own bundle id.
    private static let fallbackGroupID = "group.ArmaniZuniga.WaniKaniHelper"

    // MARK: - App Group resolution

    /// Resolved once, at first use, by asking the OS which candidate group this target can actually
    /// open — `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil for any group not
    /// in the running target's entitlements. Nothing is hardcoded for a fork to edit: enabling
    /// `group.<your app bundle id>` in Signing & Capabilities is enough.
    ///
    /// iOS has no API to read your own entitlements (SecTask is macOS-only), so candidates are
    /// probed in order rather than enumerated.
    private(set) static var resolved: (id: String, container: URL)? = {
        for candidate in candidateGroupIDs {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) {
                return (candidate, url)
            }
        }
        return nil
    }()

    private static var candidateGroupIDs: [String] {
        var ids = ["group." + hostBundleIdentifier]
        if !ids.contains(fallbackGroupID) { ids.append(fallbackGroupID) }
        return ids
    }

    /// The widget extension's bundle id is the app's with a suffix appended (`....WaniWidget`), so
    /// drop the last component when running inside an appex — both targets then derive the same
    /// group from whatever the app is called.
    private static var hostBundleIdentifier: String {
        let id = Bundle.main.bundleIdentifier ?? ""
        guard Bundle.main.bundleURL.pathExtension == "appex" else { return id }
        return id.split(separator: ".").dropLast().joined(separator: ".")
    }

    // MARK: - Container

    static var appGroupID: String { resolved?.id ?? fallbackGroupID }

    static var containerURL: URL? { resolved?.container }

    static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    static func save(_ words: [WidgetWord]) {
        guard let url = fileURL else {
            print("""
                WidgetShared: no App Group container. Enable the App Groups capability on both the \
                app and widget targets, using \(candidateGroupIDs.first ?? fallbackGroupID).
                """)
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
