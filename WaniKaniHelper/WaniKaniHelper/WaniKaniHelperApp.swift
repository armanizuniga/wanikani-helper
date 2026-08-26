// App entry point. Configures the SwiftData model container for CachedSubject and KanaSRSEntry,
// bootstraps the SubjectStore and KanaSRSStore, and routes between AuthView (first launch)
// and HomeView (authenticated) based on whether a valid API key is stored.
import SwiftUI
import SwiftData

@main
struct WaniKaniHelperApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [CachedSubject.self, KanaSRSEntry.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: SubjectStore?
    @State private var kanaStore: KanaSRSStore?
    @State private var apiKey: String? = {
        // Migrate from UserDefaults to Keychain on first run after update
        if let legacy = UserDefaults.standard.string(forKey: "apiKey") {
            KeychainService.save(legacy)
            UserDefaults.standard.removeObject(forKey: "apiKey")
        }
        return KeychainService.load()
    }()
    @State private var currentUser: WKUserData? = {
        if let data = UserDefaults.standard.data(forKey: "cachedUser"),
           let cached = try? JSONDecoder().decode(WKUserData.self, from: data) {
            return cached
        }
        return nil
    }()

    var body: some View {
        Group {
            if let store {
                if let user = currentUser, let kanaStore {
                    HomeView(user: user, store: store, kanaStore: kanaStore) { key, updatedUser in
                        KeychainService.save(key)
                        if let data = try? JSONEncoder().encode(updatedUser) {
                            UserDefaults.standard.set(data, forKey: "cachedUser")
                        }
                        apiKey = key
                        currentUser = updatedUser
                    }
                } else {
                    AuthView { key, user in
                        KeychainService.save(key)
                        apiKey = key
                        currentUser = user
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            await Task.detached(priority: .userInitiated) {
                SentenceStore.shared.load()
            }.value
            let newStore = SubjectStore(context: modelContext)
            newStore.importFromBundle()
            store = newStore
            kanaStore = KanaSRSStore(context: modelContext)

            // Seed the Lock Screen widget from whatever pass state we already have on disk,
            // so it's populated even offline before the API sync below runs.
            WidgetWordSync.update(using: newStore)
            guard let key = apiKey else { return }
            await WaniKaniAPIClient.shared.configure(apiKey: key)

            // Show cached user immediately so the dashboard is visible even if API is down
            if let data = UserDefaults.standard.data(forKey: "cachedUser"),
               let cached = try? JSONDecoder().decode(WKUserData.self, from: data) {
                currentUser = cached
            }

            // Try to refresh from API; silently keep cached data on failure
            if let fresh = try? await WaniKaniAPIClient.shared.fetchUser() {
                currentUser = fresh
                if let data = try? JSONEncoder().encode(fresh) {
                    UserDefaults.standard.set(data, forKey: "cachedUser")
                }
            }

            // Sync passed status in background so isPassed is accurate across all views
            Task {
                if let passedIds = try? await WaniKaniAPIClient.shared.fetchPassedSubjectIds() {
                    newStore.applyPassedStatus(passedIds: passedIds)
                    // Refresh the widget now that learned status is up to date.
                    WidgetWordSync.update(using: newStore)
                }
            }
        }
    }
}
