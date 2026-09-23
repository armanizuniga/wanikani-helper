// Hand-off point between App Intents and the UI. An intent that opens the app (Start Reviews,
// Start Lessons, Start Practice) sets `pending`; HomeView watches it, navigates, and clears it.
// Survives a cold launch: if HomeView isn't on screen yet, it picks the request up when it appears.
import Foundation
import Observation

@Observable
@MainActor
final class AppRouter {
    static let shared = AppRouter()

    enum Destination: Equatable {
        case reviews
        case lessons
        case practice(PracticeKind)
        case subject(Int)   // detail sheet for one kanji/vocab item (Spotlight, Open Word)
    }

    var pending: Destination?

    private init() {}
}
