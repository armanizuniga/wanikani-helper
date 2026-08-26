// This view displays all WaniKani kanji grouped by level in a scrollable grid.
// Learned kanji (passed on WaniKani) are shown in pink; unlearned ones are greyed out.
// Passed status is synced at app launch; this view reads the already-current local state.
import SwiftUI

struct KanjiProgressView: View {
    let store: SubjectStore

    @State private var levels: [(level: Int, kanji: [CachedSubject])] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    private let pink = Color("AccentPink")

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                ForEach(levels, id: \.level) { group in
                    let passed = group.kanji.filter { $0.isPassed }.count
                    let total = group.kanji.count

                    Section {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(group.kanji, id: \.id) { kanji in
                                kanjiCell(kanji)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    } header: {
                        levelHeader(level: group.level, passed: passed, total: total)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Kanji Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            levels = store.allKanjiByLevel()
        }
    }

    // MARK: - Level header

    private func levelHeader(level: Int, passed: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            Text("Level \(level)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Text("\(passed)/\(total)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            if passed == total {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(pink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Kanji cell

    private func kanjiCell(_ kanji: CachedSubject) -> some View {
        let learned = kanji.isPassed
        let char = kanji.characters ?? kanji.slug ?? "?"

        return Text(char)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(learned ? .white : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(learned ? pink : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
