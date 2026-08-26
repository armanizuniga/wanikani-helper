// Displays an AI-generated example sentence card inline within lesson and review screens.
// Works with either AppleFoundationBackend (iOS 26+) or QwenBackend (MLX).
import SwiftUI
import Translation

struct InlineExampleCard: View {
    let subjectId: Int
    let characters: String
    let reading: String?
    let meaning: String
    let store: SubjectStore

    @State private var service = ExampleGeneratorService()
    @State private var showTranslation = false
    @State private var question = ""

    var body: some View {
        Group {
            switch service.state {
            case .idle:
                if AIModelManager.shared.activeBackend == .claude {
                    generateButton
                } else {
                    Color.clear.frame(height: 0)
                }
            case .generating:
                generatingView
            case .result(let example):
                resultView(example: example)
            case .failed:
                failedView
            }
        }
        .task(id: subjectId) {
            // Claude is a paid API — don't auto-generate while the user speeds through reviews.
            // They tap "Generate example" instead. On-device/bundled backends are free, so auto-run.
            guard AIModelManager.shared.activeBackend != .claude else {
                service.reset()
                return
            }
            await service.generate(
                subjectId: subjectId,
                characters: characters,
                reading: reading,
                meaning: meaning
            )
        }
    }

    private var generateButton: some View {
        Button {
            Task {
                await service.generate(
                    subjectId: subjectId,
                    characters: characters,
                    reading: reading,
                    meaning: meaning
                )
            }
        } label: {
            Label("Generate example", systemImage: "sparkles")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: - Generating

    private var generatingView: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.75)
            Text("Generating example…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Result

    private func resultView(example: AIGeneratedContent) -> some View {
        let kanjiHits = store.kanjiInSentence(example.japanese)

        return VStack(alignment: .leading, spacing: 12) {
            sentenceBlock(japanese: example.japanese)

            HStack {
                if #available(iOS 17.4, *) {
                    Button { showTranslation = true } label: {
                        Label("Translate", systemImage: "translate")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    Task {
                        await service.regenerate(
                            subjectId: subjectId,
                            characters: characters,
                            reading: reading,
                            meaning: meaning
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !kanjiHits.isEmpty {
                kanjiBreakdown(kanjiHits)
            }

            if AIModelManager.shared.activeBackend == .claude {
                grammarExplanation(sentence: example.japanese)
            }
        }
        .modifier(InlineTranslationPresenter(isPresented: $showTranslation, text: example.japanese))
    }

    // MARK: - Grammar explanation (Claude only)

    @ViewBuilder
    private func grammarExplanation(sentence: String) -> some View {
        switch service.explanation {
        case .idle:
            Button {
                Task { await service.explainSentence(sentence) }
            } label: {
                Label("Explain grammar", systemImage: "text.book.closed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .loading:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Explaining…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .active:
            chatThread

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text("Couldn't explain")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Retry") {
                    Task { await service.explainSentence(sentence) }
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    private var chatThread: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Grammar")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(service.chat) { message in
                chatBubble(message)
            }

            if service.isReplying {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Thinking…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            chatInput
        }
    }

    @ViewBuilder
    private func chatBubble(_ message: ExampleGeneratorService.ChatMessage) -> some View {
        switch message.role {
        case .assistant:
            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color("AccentPink").opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var chatInput: some View {
        HStack(spacing: 8) {
            TextField("Ask a follow-up…", text: $question, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .onSubmit { sendQuestion() }
            Button {
                sendQuestion()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(canSend ? Color("AccentPink") : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var canSend: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isReplying
    }

    private func sendQuestion() {
        guard canSend else { return }
        let q = question
        question = ""
        Task { await service.askFollowUp(q) }
    }

    private func kanjiBreakdown(_ kanji: [CachedSubject]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kanji in sentence")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kanji, id: \.id) { k in
                        VStack(spacing: 3) {
                            Text(k.characters ?? "")
                                .font(.system(size: 20))
                                .foregroundStyle(Color("AccentPink"))
                            Text(k.meanings.first ?? "")
                                .font(.caption2.bold())
                                .foregroundStyle(Color("AccentPink"))
                                .lineLimit(1)
                        }
                        .frame(minWidth: 48)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(Color("AccentPink").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func sentenceBlock(japanese: String) -> some View {
        SelectableLabel(text: japanese, font: .systemFont(ofSize: 22), color: .label)
    }

    // MARK: - Failed

    private var failedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text("Couldn't generate example")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                Task {
                    await service.generate(
                        subjectId: subjectId,
                        characters: characters,
                        reading: reading,
                        meaning: meaning
                    )
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct InlineTranslationPresenter: ViewModifier {
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
