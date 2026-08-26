// Entry screen for Kanji Review. Loads the user's kanji grouped by SRS-stage category, shows each
// category with a live count, lets the user multi-select which to practice, then starts a local
// session over the union of the selected categories.
import SwiftUI

struct KanjiReviewSetupView: View {
    let store: SubjectStore

    @State private var service: KanjiReviewService
    @State private var selected: Set<KanjiCategory> = []
    @State private var showSession = false

    init(store: SubjectStore) {
        self.store = store
        _service = State(initialValue: KanjiReviewService(store: store))
    }

    var body: some View {
        Group {
            if service.isLoadingCategories {
                loadingView
            } else if let error = service.categoryError {
                errorView(error)
            } else if !service.hasAnyKanji {
                noKanjiView
            } else {
                categoryList
            }
        }
        .navigationTitle("Kanji Review")
        .navigationBarTitleDisplayMode(.inline)
        .task { if service.counts.isEmpty { await service.loadCategories() } }
        .navigationDestination(isPresented: $showSession) {
            KanjiReviewSessionView(service: service, store: store)
        }
    }

    // MARK: - Category list

    private var categoryList: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(KanjiCategory.allCases) { category in
                        categoryRow(category)
                    }
                } footer: {
                    Text("Practice only — results are not sent to WaniKani and won't change your SRS.")
                }
            }
            .listStyle(.insetGrouped)

            startBar
        }
    }

    private func categoryRow(_ category: KanjiCategory) -> some View {
        let count = service.count(for: category)
        let isOn = selected.contains(category)
        let disabled = count == 0

        return Button {
            if isOn { selected.remove(category) } else { selected.insert(category) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(color(for: category))
                    .frame(width: 12, height: 12)
                Text(category.title)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private var startBar: some View {
        let total = service.selectedTotal(selected)
        let cap = KanjiReviewService.sessionCap
        let sessionSize = min(total, cap)

        return VStack(spacing: 8) {
            if total > cap {
                Text("\(total) selected — a session covers \(cap) at a time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                service.startSession(categories: selected)
                showSession = true
            } label: {
                Text(total > 0 ? "Start • \(sessionSize) kanji" : "Select a category")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(total > 0 ? Color.accentColor : Color.secondary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(total == 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private func color(for category: KanjiCategory) -> Color {
        switch category {
        case .apprentice:  return Color("AccentPink")
        case .guru:        return Color("WKPlum")
        case .master:      return Color("WKTeal")
        case .enlightened: return Color("WKGreen")
        case .burned:      return Color(.darkGray)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your kanji…")
                .foregroundStyle(.secondary)
        }
    }

    private var noKanjiView: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No kanji yet")
                .font(.title3.bold())
            Text("Once you've started learning kanji on WaniKani, they'll show up here to practice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Couldn't load")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await service.loadCategories() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }
}
