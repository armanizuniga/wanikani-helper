// This view is the main dashboard shown after authentication. Displays the daily review goal,
// lesson and review action tiles, current level progress, kana practice shortcuts, an AI reading
// practice card, and a Tools section with kanji progress and API key management.
import SwiftUI
import UIKit

struct HomeView: View {
    let user: WKUserData
    let store: SubjectStore
    let kanaStore: KanaSRSStore
    var onApiKeyUpdated: (String, WKUserData) -> Void = { _, _ in }
    var onSignOut: () -> Void = {}

    @State private var kanaScript: KanaScript?

    enum KanaScript: String, Identifiable {
        case hiragana, katakana
        var id: String { rawValue }
    }

    @State private var summary: WKSummaryData?
    @State private var isLoadingSummary = false
    @State private var lessonAssignmentCount: Int = 0
    @State private var showReview = false
    @State private var showKanjiReview = false
    @State private var showLessons = false
    @State private var dailyCompleted: Int = DailyGoal.completed
    @State private var levelProgress: LevelProgress?
    @State private var levelAssignments: [WKResource<WKAssignmentData>] = []
    @State private var showingDetailType: SubjectDetailType?
    @State private var showKanjiProgress = false
    @State private var offlineWarning: String?

    var reviewCount: Int {
        let now = Date()
        return summary?.reviews
            .filter { $0.availableAt <= now }
            .flatMap { $0.subjectIds }
            .count ?? 0
    }

    var todaysTotalReviews: Int {
        guard let summary else { return dailyCompleted }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let fromSummary = summary.reviews
            .filter { $0.availableAt >= startOfToday && $0.availableAt < startOfTomorrow }
            .flatMap { $0.subjectIds }
            .count
        return dailyCompleted + fromSummary
    }

    var lessonCount: Int { lessonAssignmentCount }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WELCOME BACK,")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .kerning(1.5)
                            Text(user.displayName)
                                .font(.title2.bold())
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                            Text("Lv \(user.level)")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color("AccentPink"))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                }

                Section {
                    dailyGoalRow
                }
                .listSectionSpacing(20)

                Section {
                    VStack(spacing: 8) {
                        // Lessons tile
                        if lessonCount > 0 {
                            Button {
                                showLessons = true
                            } label: {
                                Label("Start Lessons (\(lessonCount))", systemImage: "book.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 22)
                                    .padding(.horizontal, 16)
                                    .background(Color("AccentPink"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(DepthButtonStyle(depth: 5, depthColor: Color("AccentDeep")))
                        } else {
                            HStack {
                                Label("No lessons available", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                // Invisible placeholder mirrors the "Next in" block so
                                // both tiles always compute to the same height
                                nextInPlaceholder.hidden()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 22)
                            .padding(.horizontal, 16)
                            .background(Color("AccentPink").opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Reviews tile
                        if reviewCount > 0 {
                            Button {
                                showReview = true
                            } label: {
                                Label("Start Reviews (\(reviewCount))", systemImage: "play.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 22)
                                    .padding(.horizontal, 16)
                                    .background(Color("WKTeal"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(DepthButtonStyle(depth: 5, depthColor: Color("WKTealDeep")))
                        } else {
                            HStack {
                                Label("No reviews available", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                if let next = summary?.nextReviewsAt {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Next in")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                        Text(next, style: .relative)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                } else {
                                    nextInPlaceholder.hidden()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 22)
                            .padding(.horizontal, 16)
                            .background(Color("WKTeal").opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Kanji Review tile — always available (local practice, not gated by the review queue)
                        Button {
                            showKanjiReview = true
                        } label: {
                            Label("Kanji Review", systemImage: "square.stack.3d.up.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 22)
                                .padding(.horizontal, 16)
                                .background(Color(red: 0.64, green: 0.57, blue: 0.86))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(DepthButtonStyle(depth: 5, depthColor: Color(red: 0.50, green: 0.43, blue: 0.74)))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 14, leading: 0, bottom: 8, trailing: 0))
                }
                .listSectionSpacing(10)

                Section {
                    levelProgressRow
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listSectionSpacing(10)

                Section {
                    kanaPracticeRow
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                }
                .listSectionSpacing(10)

                if AIModelManager.shared.isAnyBackendAvailable {
                    Section {
                        DailySentenceCard(store: store, level: user.level)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    }
                    .listSectionSpacing(10)
                }

                Section("Tools") {
                    Button {
                        showKanjiProgress = true
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("AccentPink").opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: "rectangle.grid.3x2.fill")
                                        .foregroundStyle(Color("AccentPink"))
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            Text("Kanji Progress")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SettingsView(
                            user: user,
                            store: store,
                            onApiKeyUpdated: onApiKeyUpdated,
                            onSignOut: onSignOut
                        )
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundStyle(.gray)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            Text("Settings")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .padding(.top, -35)
            .refreshable { await loadSummary() }
            .task { await loadSummary() }
            .navigationDestination(isPresented: $showReview) {
                ReviewSessionView(store: store)
            }
            .navigationDestination(isPresented: $showKanjiReview) {
                KanjiReviewSetupView(store: store)
            }
            .navigationDestination(isPresented: $showLessons) {
                LessonSessionView(store: store)
            }
            .navigationDestination(item: $kanaScript) { script in
                KanaReviewView(store: kanaStore, script: script.rawValue)
            }
            .navigationDestination(isPresented: $showKanjiProgress) {
                KanjiProgressView(store: store)
            }
            .sheet(item: $showingDetailType) { type in
                LevelDetailSheet(
                    type: type,
                    level: user.level,
                    assignments: levelAssignments,
                    store: store
                )
            }
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    Color.clear
                        .background(.ultraThinMaterial)
                        .frame(height: 50)
                        .ignoresSafeArea(edges: .top)
                }
                .frame(height: 0)
            }
            .overlay(alignment: .top) {
                if let warning = offlineWarning {
                    OfflineBanner(message: warning) { offlineWarning = nil }
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: offlineWarning)
        }
    }

    // MARK: - Daily Goal

    private var dailyGoalRow: some View {
        let total = todaysTotalReviews
        let progress = total > 0 ? CGFloat(dailyCompleted) / CGFloat(total) : 0
        let pct = total > 0 ? Int(progress * 100) : 0
        let pink = Color("AccentPink")

        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(pink, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.9), value: progress)
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Goal")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Text(total > 0 ? "\(dailyCompleted) / \(total) Reviews" : "No reviews today")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Level Progress

    private var levelProgressRow: some View {
        let lp = levelProgress
        let kanjiTotal = lp?.kanjiTotal ?? 0
        // WaniKani levels you up once 90% of the level's kanji have reached Guru, so progress is
        // a count of passed kanji against that threshold. Partial credit for stages below Guru
        // would let the bar read 100% while too few kanji had actually passed.
        let requiredKanji = Int(ceil(Double(kanjiTotal) * 0.9))

        let kanjiAssignments = levelAssignments.filter {
            !$0.data.hidden && $0.data.subjectTypeEnum == .kanji
        }
        let passedKanji = kanjiAssignments.filter { $0.data.passedAt != nil }.count
        let kanjiProgress: CGFloat = requiredKanji > 0 ? min(1.0, CGFloat(passedKanji) / CGFloat(requiredKanji)) : 0
        let remainingKanji = max(0, requiredKanji - passedKanji)
        let levelUpLabel: String = {
            guard requiredKanji > 0 else { return "" }
            guard remainingKanji > 0 else { return "Ready to level up!" }
            return "Guru \(remainingKanji) more kanji to level up"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            // Kanji level-up bar
            HStack {
                Text("Level \(user.level) → \(user.level + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(levelUpLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(remainingKanji == 0 && requiredKanji > 0 ? Color("WKGreen") : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color("AccentPink"))
                        .frame(width: geo.size.width * kanjiProgress)
                        .animation(.easeOut(duration: 0.7), value: kanjiProgress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button { showingDetailType = .radical } label: {
                    subjectTile(label: "Radicals", passed: lp?.radicalPassed ?? 0, total: lp?.radicalTotal ?? 0, color: Color("WKTeal"))
                }
                .buttonStyle(.plain)
                Button { showingDetailType = .kanji } label: {
                    subjectTile(label: "Kanji", passed: lp?.kanjiPassed ?? 0, total: lp?.kanjiTotal ?? 0, color: Color("AccentPink"))
                }
                .buttonStyle(.plain)
                Button { showingDetailType = .vocab } label: {
                    subjectTile(label: "Vocab", passed: lp?.vocabPassed ?? 0, total: lp?.vocabTotal ?? 0, color: Color("WKPlum"))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
        }
        .padding(.vertical, 6)
    }

    private func subjectTile(label: String, passed: Int, total: Int, color: Color) -> some View {
        let progress = total > 0 ? CGFloat(passed) / CGFloat(total) : 0

        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .kerning(0.5)

            Text("\(passed)/\(total)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 0.7), value: progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // Invisible size-reference for the "Next in / time" block.
    // Both inactive tiles include this (one hidden, one visible) so SwiftUI
    // always gives them the same height regardless of whether a next-review
    // time is available.
    private var nextInPlaceholder: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Next in").font(.caption)
            Text("0h 0m").font(.caption.bold())
        }
    }

    // MARK: - Kana Practice

    private var kanaPracticeRow: some View {
        HStack(spacing: 8) {
            kanaButton(script: .hiragana, label: "Hiragana", color: .blue)
            kanaButton(script: .katakana, label: "Katakana", color: .orange)
        }
    }

    private func kanaButton(script: KanaScript, label: String, color: Color) -> some View {
        let mastered = kanaStore.masteredCount(script: script.rawValue)
        let total    = kanaStore.totalCount(script: script.rawValue)
        let progress = total > 0 ? CGFloat(mastered) / CGFloat(total) : 0

        return Button { kanaScript = script } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color.opacity(0.6))
                }

                Text("\(mastered)/\(total) mastered")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geo.size.width * progress)
                            .animation(.easeOut(duration: 0.7), value: progress)
                    }
                }
                .frame(height: 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadSummary() async {
        isLoadingSummary = true
        do {
            // Use local subject IDs to filter assignments — more reliable than the
            // API's levels= parameter, which can silently mismatch.
            let localTotals = store.subjectTotals(level: user.level)
            let localIds    = store.subjectIds(level: user.level)

            async let summaryFetch     = WaniKaniAPIClient.shared.fetchSummary()
            async let assignmentsFetch = WaniKaniAPIClient.shared.fetchLevelAssignments(subjectIds: localIds)
            async let lessonsFetch     = WaniKaniAPIClient.shared.fetchLessonAssignments()
            let s = try await summaryFetch
            let a = try await assignmentsFetch
            let l = try await lessonsFetch
            summary = s
            levelAssignments = a
            let lessonSubjectIds = l.map { $0.data.subjectId }
            var lessonSubjectMap = store.subjectMap(ids: lessonSubjectIds)

            // Some lesson subjects may be newer than our bundled snapshot and missing locally.
            // Fetch and cache them so the lessons are counted here and studyable in the session.
            let missingLessonIds = lessonSubjectIds.filter { lessonSubjectMap[$0] == nil }
            if !missingLessonIds.isEmpty,
               let fetched = try? await WaniKaniAPIClient.shared.fetchSubjects(ids: missingLessonIds),
               !fetched.isEmpty {
                store.upsert(fetchedSubjects: fetched)
                lessonSubjectMap = store.subjectMap(ids: lessonSubjectIds)
            }
            lessonAssignmentCount = l.filter { $0.id != nil && lessonSubjectMap[$0.data.subjectId] != nil }.count

            // Derive progress counts from the same response so tile numbers and
            // individual item bars always reflect identical data.
            let visible  = a.filter { !$0.data.hidden }
            let radicals = visible.filter { $0.data.subjectTypeEnum == .radical }
            let kanji    = visible.filter { $0.data.subjectTypeEnum == .kanji }
            let vocab    = visible.filter { $0.data.subjectTypeEnum?.isVocab == true }
            levelProgress = LevelProgress(
                radicalPassed: radicals.filter { $0.data.passedAt != nil }.count,
                radicalTotal:  localTotals.radicalTotal,
                kanjiPassed:   kanji.filter    { $0.data.passedAt != nil }.count,
                kanjiTotal:    localTotals.kanjiTotal,
                vocabPassed:   vocab.filter    { $0.data.passedAt != nil }.count,
                vocabTotal:    localTotals.vocabTotal
            )
        } catch {
            if error.isNetworkFailure {
                offlineWarning = "Offline: Failed to fetch user information"
            }
        }
        dailyCompleted = DailyGoal.completed
        isLoadingSummary = false
    }

}
