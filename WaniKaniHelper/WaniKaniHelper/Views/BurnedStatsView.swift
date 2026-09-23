// Stats screen for a local burned-subject SRS, reached from the bottom of Kanji Review or Vocab
// Review. `kind` decides which schedule it reads and how the copy is worded.
//
// WaniKani retires a burned item and never shows it again, so this app's own schedule is the only
// record of whether it has actually held up. This screen surfaces that record: how far each item
// has been pushed out, and — the part the user is really after — which burned items they still get
// wrong versus which ones are solid.
//
// Everything here is local. None of it is on WaniKani and none of it is sent there.
import SwiftUI

struct BurnedStatsView: View {
    let kind: PracticeKind
    let store: SubjectStore
    let burnedStore: any BurnedSRSStoring

    @State private var stats: [BurnedStat] = []
    @State private var stageCounts: [Int] = []
    @State private var subjects: [Int: CachedSubject] = [:]

    private let strongColor = Color("WKGreen")
    private let weakColor = Color("WKRed")

    // MARK: - Derived rankings

    private var practiced: [BurnedStat] { stats.filter(\.isPracticed) }

    /// Every item carrying a miss it hasn't worked off yet, worst first. A miss is the whole
    /// signal — a burned item the user still gets wrong is exactly what this screen exists to
    /// surface — but it's cleared by a streak, so nothing is stuck here permanently.
    private var needsWork: [BurnedStat] {
        practiced
            .filter(\.needsWork)
            .sorted { $0.rankScore < $1.rankScore }
    }

    /// Clean records plus everything that has answered its way back, most-proven first.
    private var strongest: [BurnedStat] {
        practiced
            .filter(\.isStrong)
            .sorted { $0.rankScore > $1.rankScore }
    }

    private var unpracticedCount: Int { stats.count - practiced.count }

    var body: some View {
        ScrollView {
            if stats.isEmpty {
                emptyView
                    .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    summaryRow
                    stageChart
                    if !needsWork.isEmpty {
                        rankingSection(
                            title: "Needs Work",
                            subtitle: "Missed here — \(BurnedStat.redemptionStreak) right in a row clears it",
                            icon: "exclamationmark.triangle.fill",
                            tint: weakColor,
                            entries: needsWork
                        )
                    }
                    if !strongest.isEmpty {
                        rankingSection(
                            title: "Strongest",
                            subtitle: "Clean or recovered — most-proven first",
                            icon: "checkmark.seal.fill",
                            tint: strongColor,
                            entries: strongest
                        )
                    }
                    footerNote
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Burned Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func load() {
        stats = burnedStore.stats()
        stageCounts = burnedStore.stageCounts()
        subjects = store.subjectMap(ids: stats.map(\.subjectId))
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryTile(value: stats.count, label: "Burned", color: Color("WKPlum"))
            summaryTile(value: practiced.count, label: "Practiced", color: Color("WKTeal"))
            summaryTile(value: burnedStore.dueCount, label: "Due Now", color: Color("AccentPink"))
        }
    }

    private func summaryTile(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stage distribution

    private var stageChart: some View {
        // Scale bars against the busiest stage rather than the total: most users pile up in one or
        // two stages, and scaling against the total would flatten every other bar to a sliver.
        let peak = max(stageCounts.max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Review Stages", subtitle: "How far out each burned item is scheduled")

            VStack(spacing: 6) {
                ForEach(Array(stageCounts.enumerated()), id: \.offset) { stage, count in
                    HStack(spacing: 10) {
                        Text(BurnedSRS.stageLabel(stage))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(stageColor(stage))
                                    .frame(width: max(0, geo.size.width * CGFloat(count) / CGFloat(peak)))
                            }
                        }
                        .frame(height: 14)

                        Text("\(count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(count > 0 ? .primary : .tertiary)
                            .frame(width: 30, alignment: .leading)
                    }
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Warm at the short intervals, cool at the long ones, so the chart reads as a gradient from
    /// "still shaky" to "well retained" at a glance.
    private func stageColor(_ stage: Int) -> Color {
        switch stage {
        case 0:    return Color(.systemGray2)
        case 1, 2: return Color("AccentPink")
        case 3, 4: return Color("WKGold")
        case 5, 6: return Color("WKTeal")
        default:   return strongColor
        }
    }

    // MARK: - Rankings

    private func rankingSection(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        entries: [BurnedStat]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                sectionTitle(title, subtitle: subtitle)
            }

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, stat in
                    statRow(stat, tint: tint)
                    if index < entries.count - 1 {
                        Divider().padding(.leading, kind == .kanji ? 56 : 100)
                    }
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statRow(_ stat: BurnedStat, tint: Color) -> some View {
        let subject = subjects[stat.subjectId]

        return HStack(spacing: 12) {
            // Kanji are always one glyph, so a fixed column keeps the rows aligned. Vocabulary runs
            // several characters wide and would be clipped by that, so it gets a wider box and
            // shrinks to fit instead.
            Text(subject?.characters ?? subject?.slug ?? "?")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: kind == .kanji ? 32 : 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(subject?.meanings.first ?? "—")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detailLine(stat))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(accuracyLabel(stat))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // Record, schedule, and — for anything touched by the streak rule — where it stands with it.
    private func detailLine(_ stat: BurnedStat) -> String {
        var parts = [
            "\(stat.totalCorrect) right",
            "\(stat.totalIncorrect) wrong",
            BurnedSRS.stageLabel(stat.stage),
        ]
        if stat.isRecovered {
            parts.append("recovered")
        } else if stat.needsWork {
            parts.append("\(stat.answersToRecover) to clear")
        }
        return parts.joined(separator: " · ")
    }

    private func accuracyLabel(_ stat: BurnedStat) -> String {
        guard let accuracy = stat.accuracy else { return "—" }
        return "\(Int((accuracy * 100).rounded()))%"
    }

    // MARK: - Chrome

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            if unpracticedCount > 0 {
                Text("\(unpracticedCount) burned \(kind.pluralNoun) haven't come up in practice here yet, so they aren't ranked.")
            }
            Text("A missed item rejoins Strongest once you answer it right \(BurnedStat.redemptionStreak) times in a row.")
            Text("Based only on \(kind.reviewTitle) practice in this app — nothing here affects your WaniKani SRS.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No burned \(kind.pluralNoun) yet")
                .font(.title3.bold())
            Text("Once you burn \(kind.formalPluralNoun) on WaniKani they'll be tracked here, and practicing it in \(kind.reviewTitle) builds this breakdown.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
