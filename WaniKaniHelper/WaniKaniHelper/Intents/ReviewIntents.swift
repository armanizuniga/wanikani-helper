// App Intents exposed to Siri, Spotlight, Shortcuts and the Action button. Check Reviews answers
// in place without opening the app; the Start intents open the app and hand navigation to
// AppRouter. Phrases live in WaniKaniShortcuts.
import AppIntents
import SwiftUI

enum WaniKaniIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn
    case unreachable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn: return "Open WaniKani Helper and sign in with your API key first."
        case .unreachable: return "Couldn't reach WaniKani. Check your connection and try again."
        }
    }
}

// MARK: - Check Reviews

struct CheckReviewsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Reviews"
    static let description = IntentDescription("See how many WaniKani reviews and lessons are waiting.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Siri can run this before the app has launched, so the API client may not be set up yet.
        guard let key = KeychainService.load() else { throw WaniKaniIntentError.notSignedIn }
        await WaniKaniAPIClient.shared.configure(apiKey: key)

        let summary: WKSummaryData
        let lessons: Int
        do {
            async let summaryFetch = WaniKaniAPIClient.shared.fetchSummary()
            async let lessonsFetch = WaniKaniAPIClient.shared.fetchLessonAssignments()
            summary = try await summaryFetch
            lessons = try await lessonsFetch.count
        } catch {
            throw WaniKaniIntentError.unreachable
        }

        // Same count HomeView shows: every subject whose review is already available.
        let now = Date()
        let reviews = summary.reviews
            .filter { $0.availableAt <= now }
            .flatMap(\.subjectIds)
            .count
        let nextReview = reviews == 0 ? summary.nextReviewsAt : nil

        return .result(
            dialog: IntentDialog(stringLiteral: Self.dialog(reviews: reviews, lessons: lessons, next: nextReview)),
            view: ReviewCountSnippet(reviews: reviews, lessons: lessons, nextReview: nextReview)
        )
    }

    private static func dialog(reviews: Int, lessons: Int, next: Date?) -> String {
        let reviewPart = reviews == 1 ? "1 review" : "\(reviews) reviews"
        let lessonPart = lessons == 1 ? "1 lesson" : "\(lessons) lessons"
        if reviews == 0 {
            var text = "No reviews right now, and you have \(lessonPart)."
            if let next {
                text += " Next reviews at \(next.formatted(date: .omitted, time: .shortened))."
            }
            return text
        }
        return "You have \(reviewPart) and \(lessonPart) waiting."
    }
}

private struct ReviewCountSnippet: View {
    let reviews: Int
    let lessons: Int
    let nextReview: Date?

    var body: some View {
        HStack(spacing: 12) {
            tile(value: reviews, label: "Reviews", color: Color("AccentPink"))
            tile(value: lessons, label: "Lessons", color: Color("WKTeal"))
        }
        .padding()
        .overlay(alignment: .bottom) {
            if let nextReview {
                Text("Next at \(nextReview.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
    }

    private func tile(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Start intents (open the app)

struct StartReviewsIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Reviews"
    static let description = IntentDescription("Open WaniKani Helper straight into your review session.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .reviews
        return .result()
    }
}

struct StartLessonsIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Lessons"
    static let description = IntentDescription("Open WaniKani Helper straight into your lessons.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .lessons
        return .result()
    }
}

struct StartPracticeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Burned Practice"
    static let description = IntentDescription("Open Kanji Review or Vocab Review to practice burned items.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Practice")
    var kind: PracticeKind

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .practice(kind)
        return .result()
    }
}

nonisolated extension PracticeKind: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Practice"
    static let caseDisplayRepresentations: [PracticeKind: DisplayRepresentation] = [
        .kanji: DisplayRepresentation(title: "burned kanji", synonyms: ["kanji", "kanji review"]),
        .vocabulary: DisplayRepresentation(title: "burned vocab", synonyms: ["vocab", "vocabulary", "burned vocabulary", "vocab review"]),
    ]
}
