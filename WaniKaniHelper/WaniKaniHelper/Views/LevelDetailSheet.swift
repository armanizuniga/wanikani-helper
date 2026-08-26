// This sheet displays a detailed breakdown of the user's current level progress for a selected
// subject type (radical, kanji, or vocabulary). Groups items into passed, in-progress, and
// not-started buckets, each showing the subject character and its SRS stage progress bar.
import SwiftUI

// MARK: - Types

enum SubjectDetailType: String, Identifiable {
    case radical, kanji, vocab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .radical: "Radicals"
        case .kanji:   "Kanji"
        case .vocab:   "Vocabulary"
        }
    }

    func matches(_ subjectType: SubjectType) -> Bool {
        switch self {
        case .radical: subjectType == .radical
        case .kanji:   subjectType == .kanji
        case .vocab:   subjectType.isVocab
        }
    }

    var color: Color {
        switch self {
        case .radical: Color("WKTeal")
        case .kanji:   Color("AccentPink")
        case .vocab:   Color("WKPlum")
        }
    }
}

struct SubjectProgressItem: Identifiable {
    var id: Int { subject.id }
    let subject: CachedSubject
    let srsStage: Int  // -1 = locked (no assignment)
    let isPassed: Bool // true if passedAt != nil — survives drops back to Apprentice
}

// MARK: - Sheet

struct LevelDetailSheet: View {
    let type: SubjectDetailType
    let level: Int
    let assignments: [WKResource<WKAssignmentData>]
    let store: SubjectStore

    @Environment(\.dismiss) private var dismiss

    private var items: [SubjectProgressItem] {
        let subjects = store.subjects(level: level)
            .filter { type.matches($0.subjectType) }
        let dataMap = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.data.subjectId, $0.data) }
        )
        return subjects.map { subject in
            let data = dataMap[subject.id]
            return SubjectProgressItem(
                subject:  subject,
                srsStage: data?.srsStage ?? -1,
                isPassed: data?.passedAt != nil
            )
        }
    }

    private var inProgressItems: [SubjectProgressItem] {
        items.filter { !$0.isPassed && $0.srsStage >= 1 }
            .sorted { $0.srsStage > $1.srsStage }
    }
    private var lessonItems: [SubjectProgressItem] {
        items.filter { !$0.isPassed && $0.srsStage == 0 }
    }
    private var lockedItems: [SubjectProgressItem] {
        items.filter { $0.srsStage == -1 }
    }
    private var passedItems: [SubjectProgressItem] {
        items.filter { $0.isPassed }
    }

    private var columns: [GridItem] {
        switch type {
        case .radical, .kanji:
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        case .vocab:
            return [GridItem(.adaptive(minimum: 76), spacing: 8)]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8, pinnedViews: [.sectionHeaders]) {
                    if !inProgressItems.isEmpty {
                        Section {
                            ForEach(inProgressItems) { cellView(item: $0) }
                        } header: {
                            sectionHeader("In Progress")
                        }
                    }
                    if !lessonItems.isEmpty {
                        Section {
                            ForEach(lessonItems) { cellView(item: $0) }
                        } header: {
                            sectionHeader("Available in Lessons")
                        }
                    }
                    if !lockedItems.isEmpty {
                        Section {
                            ForEach(lockedItems) { cellView(item: $0) }
                        } header: {
                            sectionHeader("Locked")
                        }
                    }
                    if !passedItems.isEmpty {
                        Section {
                            ForEach(passedItems) { cellView(item: $0) }
                        } header: {
                            sectionHeader("Passed")
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    // MARK: - Cell

    @ViewBuilder
    private func cellView(item: SubjectProgressItem) -> some View {
        let locked = item.srsStage == -1
        let isVocab = type == .vocab
        let fg: Color = locked ? Color(.tertiaryLabel) : Color(.label)

        VStack(spacing: 4) {
            characterView(item: item, foreground: fg, isVocab: isVocab)
            SRSMiniBar(srsStage: max(item.srsStage, 0), isPassed: item.isPassed)
                .opacity(locked ? 0.3 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(locked ? Color(.systemGray6) : type.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func characterView(item: SubjectProgressItem, foreground: Color, isVocab: Bool) -> some View {
        if let chars = item.subject.characters {
            Text(chars)
                .font(isVocab
                      ? .system(size: 13, weight: .bold, design: .rounded)
                      : .system(size: 20, weight: .bold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else if let urlString = item.subject.characterImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(height: 24)
        } else {
            Text(item.subject.slug ?? "?")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
    }
}

// MARK: - SRS bar

private struct SRSMiniBar: View {
    let srsStage: Int
    let isPassed: Bool

    var body: some View {
        if isPassed {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color("WKGreen"))
                .frame(maxWidth: .infinity)
                .frame(height: 3)
        } else {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < min(srsStage, 4) ? Color("AccentPink") : Color(.systemGray5))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
