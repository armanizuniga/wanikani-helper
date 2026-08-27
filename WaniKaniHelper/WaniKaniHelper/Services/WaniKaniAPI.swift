// WaniKani API v2 client. Handles authentication, pagination, and all network requests
// including fetching the user profile, summary, subjects, assignments, lesson queue, and
// submitting reviews. Also defines all WaniKani response data models (Codable structs).
import Foundation

enum WaniKaniError: LocalizedError {
    case unauthorized
    case rateLimited
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Invalid API key. Check your WaniKani settings."
        case .rateLimited: return "Rate limit hit. Slowing down..."
        case .notFound: return "Resource not found."
        case .serverError(let code): return "Server error (\(code))."
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .unknown: return "Unknown error."
        }
    }
}

// MARK: - Raw API response types

struct WKCollection<T: Decodable>: Decodable {
    let object: String
    let url: String
    let pages: WKPages
    let totalCount: Int
    let dataUpdatedAt: Date?
    let data: [T]

    enum CodingKeys: String, CodingKey {
        case object, url, pages, data
        case totalCount = "total_count"
        case dataUpdatedAt = "data_updated_at"
    }
}

struct WKPages: Decodable {
    let perPage: Int
    let nextUrl: String?
    let previousUrl: String?

    enum CodingKeys: String, CodingKey {
        case perPage = "per_page"
        case nextUrl = "next_url"
        case previousUrl = "previous_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        perPage = try c.decodeIfPresent(Int.self, forKey: .perPage) ?? 500
        nextUrl = try c.decodeIfPresent(String.self, forKey: .nextUrl)
        previousUrl = try c.decodeIfPresent(String.self, forKey: .previousUrl)
    }
}

struct WKResource<T: Decodable>: Decodable {
    let id: Int?
    let object: String
    let url: String
    let dataUpdatedAt: Date?
    let data: T

    enum CodingKeys: String, CodingKey {
        case id, object, url, data
        case dataUpdatedAt = "data_updated_at"
    }
}

// MARK: - Subject types

struct WKCharacterImage: Decodable {
    let url: String
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case url
        case contentType = "content_type"
    }
}

struct WKSubjectData: Decodable {
    let characters: String?
    let slug: String?
    let level: Int
    let hiddenAt: Date?
    let meanings: [WKMeaning]
    let readings: [WKReading]?
    let meaningMnemonic: String?
    let componentSubjectIds: [Int]?
    let characterImages: [WKCharacterImage]?

    // PNG only — AsyncImage can't render raw SVG markup
    var characterImageURL: String? {
        characterImages?.first(where: { $0.contentType == "image/png" })?.url
    }

    enum CodingKeys: String, CodingKey {
        case characters, slug, level, meanings, readings
        case hiddenAt = "hidden_at"
        case meaningMnemonic = "meaning_mnemonic"
        case componentSubjectIds = "component_subject_ids"
        case characterImages = "character_images"
    }
}

struct WKMeaning: Decodable {
    let meaning: String
    let primary: Bool
    let acceptedAnswer: Bool

    enum CodingKeys: String, CodingKey {
        case meaning, primary
        case acceptedAnswer = "accepted_answer"
    }
}

struct WKReading: Decodable {
    let reading: String
    let primary: Bool
    let acceptedAnswer: Bool

    enum CodingKeys: String, CodingKey {
        case reading, primary
        case acceptedAnswer = "accepted_answer"
    }
}

// MARK: - Assignment types

struct WKAssignmentData: Decodable {
    let subjectId: Int
    let subjectType: String
    let srsStage: Int
    let level: Int
    let availableAt: Date?
    let startedAt: Date?
    let passedAt: Date?
    let burnedAt: Date?
    let unlockedAt: Date?
    let hidden: Bool

    enum CodingKeys: String, CodingKey {
        case hidden, level
        case subjectId = "subject_id"
        case subjectType = "subject_type"
        case srsStage = "srs_stage"
        case availableAt = "available_at"
        case startedAt = "started_at"
        case passedAt = "passed_at"
        case burnedAt = "burned_at"
        case unlockedAt = "unlocked_at"
    }

    var subjectTypeEnum: SubjectType? { SubjectType(rawValue: subjectType) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subjectId = try c.decode(Int.self, forKey: .subjectId)
        subjectType = try c.decode(String.self, forKey: .subjectType)
        srsStage = try c.decode(Int.self, forKey: .srsStage)
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 0
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        availableAt = try c.decodeIfPresent(Date.self, forKey: .availableAt)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        passedAt = try c.decodeIfPresent(Date.self, forKey: .passedAt)
        burnedAt = try c.decodeIfPresent(Date.self, forKey: .burnedAt)
        unlockedAt = try c.decodeIfPresent(Date.self, forKey: .unlockedAt)
    }
}

// MARK: - User types

struct WKUserData: Codable {
    let username: String
    let level: Int
}

extension WKUserData {
    /// The name to show in the UI. Normally the real WaniKani username; in debug builds it can be
    /// overridden with a launch argument so screenshots don't expose a real account:
    ///
    ///     xcrun simctl launch booted ArmaniZuniga.WaniKaniHelper -screenshotName crabigator
    ///
    /// or tick the same argument in the scheme's Run → Arguments. Release builds always use the
    /// real username — the override isn't compiled in.
    var displayName: String {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "screenshotName"), !override.isEmpty {
            return override
        }
        #endif
        return username
    }

    // The last-known WaniKani level, cached at the app root under "cachedUser".
    // Lets services that don't receive the user object (e.g. inline examples) read the level.
    // Returns 0 when unknown.
    static var cachedLevel: Int {
        guard let data = UserDefaults.standard.data(forKey: "cachedUser"),
              let user = try? JSONDecoder().decode(WKUserData.self, from: data) else { return 0 }
        return user.level
    }
}

// MARK: - Summary types

struct WKSummaryData: Decodable {
    let lessons: [WKSummaryLesson]
    let reviews: [WKSummaryReview]
    let nextReviewsAt: Date?

    enum CodingKeys: String, CodingKey {
        case lessons, reviews
        case nextReviewsAt = "next_reviews_at"
    }
}

struct WKSummaryLesson: Decodable {
    let availableAt: Date
    let subjectIds: [Int]

    enum CodingKeys: String, CodingKey {
        case availableAt = "available_at"
        case subjectIds = "subject_ids"
    }
}

struct WKSummaryReview: Decodable {
    let availableAt: Date
    let subjectIds: [Int]

    enum CodingKeys: String, CodingKey {
        case availableAt = "available_at"
        case subjectIds = "subject_ids"
    }
}

// MARK: - Review creation

struct WKReviewResponse: Decodable {
    let id: Int
    let data: WKReviewData
}

struct WKReviewData: Decodable {
    let assignmentId: Int
    let subjectId: Int
    let startingSrsStage: Int
    let endingSrsStage: Int

    enum CodingKeys: String, CodingKey {
        case assignmentId = "assignment_id"
        case subjectId = "subject_id"
        case startingSrsStage = "starting_srs_stage"
        case endingSrsStage = "ending_srs_stage"
    }
}

// MARK: - Level progress

struct LevelProgress {
    let radicalPassed: Int
    let radicalTotal:  Int
    let kanjiPassed:   Int
    let kanjiTotal:    Int
    let vocabPassed:   Int
    let vocabTotal:    Int
}

// MARK: - SRS stage thresholds

enum SRSStage {
    static let passed = 5
    static let burned = 9
}

// MARK: - Network error detection

extension Error {
    var isNetworkFailure: Bool {
        guard let urlError = self as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - API Client

actor WaniKaniAPIClient {
    static let shared = WaniKaniAPIClient()

    private let baseURL = "https://api.wanikani.com/v2"
    private let revision = "20170710"
    private var apiKey: String = ""

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = withFractional.date(from: str) { return date }
            if let date = withoutFractional.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Core request

    private func requestURL<T: Decodable>(_ url: URL, method: String = "GET", body: Data? = nil) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(revision, forHTTPHeaderField: "Wanikani-Revision")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw WaniKaniError.unknown }

        switch http.statusCode {
        case 200...299: break
        case 401: throw WaniKaniError.unauthorized
        case 429: throw WaniKaniError.rateLimited
        case 404: throw WaniKaniError.notFound
        default: throw WaniKaniError.serverError(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WaniKaniError.decodingError(error)
        }
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw WaniKaniError.unknown }
        return try await requestURL(url, method: method, body: body)
    }

    func fetchImageData(urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(revision, forHTTPHeaderField: "Wanikani-Revision")
        return try? await URLSession.shared.data(for: req).0
    }

    // MARK: - Endpoints

    func fetchUser() async throws -> WKUserData {
        let resource: WKResource<WKUserData> = try await request("/user")
        return resource.data
    }

    func fetchSummary() async throws -> WKSummaryData {
        let resource: WKResource<WKSummaryData> = try await request("/summary")
        return resource.data
    }

    /// Fetches all subjects, paginating automatically. Calls onProgress with count fetched so far.
    func fetchAllSubjects(updatedAfter: Date? = nil, onProgress: ((Int) -> Void)? = nil) async throws -> [WKResource<WKSubjectData>] {
        var path = "/subjects?per_page=1000"
        if let date = updatedAfter {
            let formatted = ISO8601DateFormatter().string(from: date)
            path += "&updated_after=\(formatted)"
        }
        return try await paginateSubjects(startPath: path, onProgress: onProgress)
    }

    private func paginateSubjects(startPath: String, onProgress: ((Int) -> Void)?) async throws -> [WKResource<WKSubjectData>] {
        var allSubjects: [WKResource<WKSubjectData>] = []
        var nextURL: URL? = URL(string: baseURL + startPath)

        while let url = nextURL {
            let page: WKCollection<WKResource<WKSubjectData>> = try await requestURL(url)
            allSubjects.append(contentsOf: page.data)
            onProgress?(allSubjects.count)

            if let next = page.pages.nextUrl {
                nextURL = URL(string: next)
            } else {
                nextURL = nil
            }

            // Stay well under 60 req/min
            if nextURL != nil {
                try await Task.sleep(nanoseconds: 1_100_000_000) // ~1.1s between pages
            }
        }
        return allSubjects
    }

    func fetchAvailableAssignments() async throws -> [WKResource<WKAssignmentData>] {
        var all: [WKResource<WKAssignmentData>] = []
        var nextURL: URL? = URL(string: baseURL + "/assignments?immediately_available_for_review=true&per_page=500")

        while let url = nextURL {
            let page: WKCollection<WKResource<WKAssignmentData>> = try await requestURL(url)
            all.append(contentsOf: page.data)
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        return all
    }

    func fetchLevelProgress(subjectIds: [Int]) async throws -> (radicalPassed: Int, kanjiPassed: Int, vocabPassed: Int) {
        guard !subjectIds.isEmpty else { return (0, 0, 0) }
        let idsParam = subjectIds.map { "\($0)" }.joined(separator: ",")
        var all: [WKResource<WKAssignmentData>] = []
        var nextURL: URL? = URL(string: baseURL + "/assignments?subject_ids=\(idsParam)&per_page=500")
        while let url = nextURL {
            let page: WKCollection<WKResource<WKAssignmentData>> = try await requestURL(url)
            all.append(contentsOf: page.data)
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        let visible = all.filter { !$0.data.hidden }
        let radicals = visible.filter { $0.data.subjectTypeEnum == .radical }
        let kanji    = visible.filter { $0.data.subjectTypeEnum == .kanji }
        let vocab    = visible.filter { $0.data.subjectTypeEnum?.isVocab == true }
        return (
            radicals.filter { $0.data.srsStage >= SRSStage.passed }.count,
            kanji.filter    { $0.data.srsStage >= SRSStage.passed }.count,
            vocab.filter    { $0.data.srsStage >= SRSStage.passed }.count
        )
    }

    // Fetches specific subjects by ID. Used to backfill subjects that are newer than the bundled
    // snapshot (e.g. vocab WaniKani added after the bundle was built) so their lessons/reviews appear.
    func fetchSubjects(ids: [Int]) async throws -> [WKResource<WKSubjectData>] {
        guard !ids.isEmpty else { return [] }
        let idsParam = ids.map(String.init).joined(separator: ",")
        var all: [WKResource<WKSubjectData>] = []
        var nextURL: URL? = URL(string: baseURL + "/subjects?ids=\(idsParam)&per_page=1000")
        while let url = nextURL {
            let page: WKCollection<WKResource<WKSubjectData>> = try await requestURL(url)
            all.append(contentsOf: page.data)
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        return all
    }

    func fetchLevelAssignments(subjectIds: [Int]) async throws -> [WKResource<WKAssignmentData>] {
        guard !subjectIds.isEmpty else { return [] }
        let idsParam = subjectIds.map { "\($0)" }.joined(separator: ",")
        var all: [WKResource<WKAssignmentData>] = []
        var nextURL: URL? = URL(string: baseURL + "/assignments?subject_ids=\(idsParam)&per_page=500")
        while let url = nextURL {
            let page: WKCollection<WKResource<WKAssignmentData>> = try await requestURL(url)
            all.append(contentsOf: page.data)
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        return all
    }

    // All started kanji assignments (any SRS stage), for the local Kanji Review practice feature.
    // Stage 0 (still in lessons) is included by the API but filtered out by the caller via category.
    func fetchKanjiAssignments() async throws -> [WKResource<WKAssignmentData>] {
        var all: [WKResource<WKAssignmentData>] = []
        var nextURL: URL? = URL(string: baseURL + "/assignments?subject_types=kanji&per_page=500")
        while let url = nextURL {
            let page: WKCollection<WKResource<WKAssignmentData>> = try await requestURL(url)
            all.append(contentsOf: page.data)
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        return all
    }

    func fetchLessonAssignments() async throws -> [WKResource<WKAssignmentData>] {
        var all: [WKResource<WKAssignmentData>] = []
        var nextURL: URL? = URL(string: baseURL + "/assignments?immediately_available_for_lessons=true&per_page=500")
        while let url = nextURL {
            let page: WKCollection<WKResource<WKAssignmentData>> = try await requestURL(url)
            all.append(contentsOf: page.data)
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        return all
    }

    func fetchPassedSubjectIds() async throws -> Set<Int> {
        var all: Set<Int> = []
        var nextURL: URL? = URL(string: baseURL + "/assignments?passed=true&per_page=1000")
        while let url = nextURL {
            let page: WKCollection<WKResource<WKAssignmentData>> = try await requestURL(url)
            for resource in page.data {
                all.insert(resource.data.subjectId)
            }
            nextURL = page.pages.nextUrl.flatMap { URL(string: $0) }
            if nextURL != nil { try await Task.sleep(nanoseconds: 1_100_000_000) }
        }
        return all
    }

    @discardableResult
    func startAssignment(id: Int) async throws -> WKResource<WKAssignmentData> {
        try await request("/assignments/\(id)/start", method: "PUT", body: Data("{}".utf8))
    }

    func submitReview(assignmentId: Int, incorrectMeaning: Int, incorrectReading: Int) async throws -> WKReviewResponse {
        let body: [String: Any] = [
            "review": [
                "assignment_id": assignmentId,
                "incorrect_meaning_answers": incorrectMeaning,
                "incorrect_reading_answers": incorrectReading
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request("/reviews", method: "POST", body: data)
    }
}
