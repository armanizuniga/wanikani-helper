// Entry screen for the local practice features (Kanji Review and Vocab Review). Loads the user's
// subjects of the given kind grouped by SRS-stage category, shows each category with a live count,
// lets the user multi-select which to practice, then starts a local session over the union of the
// selected categories.
import SwiftUI

struct PracticeReviewSetupView: View {
    let kind: PracticeKind
    let store: SubjectStore
    let burnedStore: any BurnedSRSStoring

    @State private var service: PracticeReviewService
    @State private var selected: Set<SRSCategory> = []
    @State private var showSession = false

    init(kind: PracticeKind, store: SubjectStore, burnedStore: any BurnedSRSStoring) {
        self.kind = kind
        self.store = store
        self.burnedStore = burnedStore
        _service = State(
            initialValue: PracticeReviewService(kind: kind, store: store, burnedStore: burnedStore)
        )
    }

    var body: some View {
        Group {
            if service.isLoadingCategories {
                loadingView
            } else if let error = service.categoryError {
                errorView(error)
            } else if !service.hasAnySubjects {
                emptyStateView
            } else {
                categoryList
            }
        }
        .navigationTitle(kind.reviewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { if service.counts.isEmpty { await service.loadCategories() } }
        .navigationDestination(isPresented: $showSession) {
            PracticeReviewSessionView(service: service, store: store)
        }
    }

    // MARK: - Category list

    private var categoryList: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(SRSCategory.allCases) { category in
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

    private func categoryRow(_ category: SRSCategory) -> some View {
        let count = service.count(for: category)
        let isOn = selected.contains(category)
        let disabled = count == 0

        return Button {
            if isOn { selected.remove(category) } else { selected.insert(category) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.color)
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
        let cap = PracticeReviewService.sessionCap
        let sessionSize = min(total, cap)

        return VStack(spacing: 8) {
            burnedStatsLink
            if total > cap {
                Text("\(total) selected — a session covers \(cap) at a time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                service.startSession(categories: selected)
                showSession = true
            } label: {
                Text(total > 0 ? "Start • \(sessionSize) \(kind.pluralNoun)" : "Select a category")
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

    /// Burned items are the only category with a local schedule behind them, so they're the only
    /// ones there are stats to show. Hidden outright when none are tracked — the screen would have
    /// nothing on it.
    @ViewBuilder
    private var burnedStatsLink: some View {
        let tracked = burnedStore.trackedCount
        if tracked > 0 {
            NavigationLink {
                BurnedStatsView(kind: kind, store: store, burnedStore: burnedStore)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Burned Stats")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(tracked) tracked")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray5).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your \(kind.formalPluralNoun)…")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: kind.emptyStateSymbol)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No \(kind.formalPluralNoun) yet")
                .font(.title3.bold())
            Text("Once you've started learning \(kind.formalPluralNoun) on WaniKani, they'll show up here to practice.")
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
