// Displays a "Reading Practice" card on the home screen. Uses SentenceGeneratorService
// to generate an AI-powered Japanese sentence tailored to the user's WaniKani level.
// Works with either AppleFoundationBackend (iOS 26+) or QwenBackend (MLX).
import SwiftUI
import Translation

struct DailySentenceCard: View {
    let store: SubjectStore
    let level: Int

    @State private var service = SentenceGeneratorService()
    @State private var showTranslation = false
    @State private var tappedKanji: CachedSubject?

    private let accent = Color.indigo

    var body: some View {
        Group {
            switch service.state {
            case .idle:       idleView
            case .generating: generatingView
            case .result(let sentence, let word, let meaning):
                resultView(sentence: sentence, word: word, meaning: meaning)
            case .failed:     failedView
            }
        }
        .frame(maxWidth: .infinity)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Idle

    private var idleView: some View {
        Button { generate() } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading Practice")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(accent)
                    Text("Generate a sentence from your current vocabulary")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generating

    private var generatingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Generating…")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
    }

    // MARK: - Result

    private func resultView(sentence: AIGeneratedContent, word: String, meaning: String) -> some View {
        let kanjiHits = store.kanjiInSentence(sentence.japanese)
        // Only kanji WaniKani teaches are highlighted — they're the ones with a sheet to open.
        let unknown = KnownKanji.unknown(in: sentence.japanese, target: word)
            .filter { ch in kanjiHits.contains { $0.characters?.first == ch } }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(word)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(accent.opacity(0.15))
                    .foregroundStyle(accent)
                    .clipShape(Capsule())

                Spacer()

                Button { generate() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            SelectableLabel(
                text: sentence.japanese, font: .systemFont(ofSize: 24), color: .label,
                highlighted: unknown,
                onTapHighlight: { ch in tappedKanji = kanjiHits.first { $0.characters?.first == ch } }
            )

            if #available(iOS 17.4, *) {
                Button {
                    showTranslation = true
                } label: {
                    Label("Translate", systemImage: "translate")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            if !kanjiHits.isEmpty {
                SentenceKanjiStrip(kanji: kanjiHits, unknown: Set(unknown)) { tappedKanji = $0 }
            }
        }
        .padding(14)
        .animation(.easeOut(duration: 0.18), value: showTranslation)
        .modifier(TranslationPresenter(isPresented: $showTranslation, text: sentence.japanese))
        .sheet(item: $tappedKanji) { KanjiHintSheet(subject: $0, store: store) }
    }

    // MARK: - Failed

    private var failedView: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("Couldn't generate sentence")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") { generate() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: - Helper

    private func generate() {
        showTranslation = false
        Task { await service.generate(store: store, level: level) }
    }
}

private struct TranslationPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    func body(content: Content) -> some View {
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
    }
}
