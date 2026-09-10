// A compact review card for a single kanji, shown as a popup sheet. Used by the easy-mode kanji
// strip under a vocabulary question so the user can refresh a kanji's meaning without leaving
// the review. Read-only — nothing here grades or advances the session.
import SwiftUI

struct KanjiHintSheet: View {
    let subject: CachedSubject
    let store: SubjectStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if !subject.meanings.isEmpty {
                        hintBlock(title: "Meaning",
                                  value: subject.meanings.joined(separator: ", "),
                                  jp: false)
                    }

                    if !subject.readings.isEmpty {
                        Divider()
                        hintBlock(title: "Reading",
                                  value: subject.readings.joined(separator: ", "),
                                  jp: true)
                    }

                    let radicals = store.components(for: subject)
                    if !radicals.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("Composition")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(radicals, id: \.id) { comp in
                                        VStack(spacing: 4) {
                                            Text(comp.characters ?? comp.slug ?? "?")
                                                .font(.system(size: 20))
                                            Text(comp.meanings.first ?? "")
                                                .font(.caption2.bold())
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(subjectTypeColor(comp.subjectType))
                                        .frame(minWidth: 52)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 6)
                                        .background(subjectTypeColor(comp.subjectType).opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    if let mnemonic = subject.meaningMnemonic, !mnemonic.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("Mnemonic")
                            Text(stripWKTags(mnemonic))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(subject.characters ?? subject.slug ?? "?")
                .font(.system(size: 64))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .textSelection(.enabled)
            Text("Level \(subject.level)")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(subjectTypeColor(subject.subjectType).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func hintBlock(title: String, value: String, jp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle(title)
            Text(value)
                .font(jp ? .system(size: 24) : .system(size: 21, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - Helpers

func subjectTypeColor(_ type: SubjectType) -> Color {
    switch type {
    case .radical:                     return Color("WKTeal")
    case .kanji:                       return Color("AccentPink")
    case .vocabulary, .kanaVocabulary: return Color("WKPlum")
    }
}
