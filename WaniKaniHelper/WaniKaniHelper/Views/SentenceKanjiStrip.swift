// "Kanji in sentence" strip shared by the home Reading Practice card and the inline example card.
// Kanji the user hasn't reached Master on are shown in gold (matching the highlight in the
// sentence itself); tapping any kanji opens its detail sheet.
import SwiftUI

struct SentenceKanjiStrip: View {
    let kanji: [CachedSubject]
    let unknown: Set<Character>
    let onTap: (CachedSubject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kanji in sentence")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kanji, id: \.id) { k in
                        let color = isUnknown(k) ? Color("WKGold") : Color("AccentPink")
                        Button { onTap(k) } label: {
                            VStack(spacing: 3) {
                                Text(k.characters ?? "")
                                    .font(.system(size: 20))
                                Text(k.meanings.first ?? "")
                                    .font(.caption2.bold())
                                    .lineLimit(1)
                            }
                            .foregroundStyle(color)
                            .frame(minWidth: 48)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .background(color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if kanji.contains(where: isUnknown) {
                Text("Gold kanji aren't at Master yet. Tap one to review it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func isUnknown(_ k: CachedSubject) -> Bool {
        k.characters?.first.map(unknown.contains) ?? false
    }
}
