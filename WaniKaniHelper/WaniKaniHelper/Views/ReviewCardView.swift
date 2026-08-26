// Service-agnostic quiz card shared by the WaniKani review session and the local Kanji Review
// practice session. Renders one ReviewItem — the subject, a multiple-choice grid, and (once
// answered) a detail card. Selecting a choice and advancing are delegated via closures so each
// host controls grading and whether results are submitted anywhere.
import SwiftUI
import UIKit

struct ReviewCardView: View {
    let item: ReviewItem
    let store: SubjectStore
    let onSelect: (String) -> Void
    let onConfirm: () -> Void

    var body: some View {
        let isAnswered = item.selectedChoice != nil

        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    subjectCard

                    // Push choices to roughly dock height
                    Color.clear.frame(height: max(0, geo.size.height * 0.18))

                    multipleChoiceGrid
                        .overlay(alignment: .top) {
                            if isAnswered {
                                nextButton
                                    .offset(y: -66)
                                    .transition(.opacity)
                            }
                        }

                    if isAnswered {
                        answerCard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 82)
                .padding(.bottom, 32)
                .animation(.easeOut(duration: 0.2), value: isAnswered)
            }
        }
    }

    // MARK: - Next button

    private var nextButton: some View {
        let correct = item.choiceWasCorrect == true
        let btnColor: Color = correct ? Color("WKGreen") : Color("WKRed")
        let depth: Color    = correct ? Color(red: 0.05, green: 0.45, blue: 0.18) : Color(red: 0.55, green: 0.05, blue: 0.05)

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.18)) {
                onConfirm()
            }
        } label: {
            Text("Next")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(btnColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(DepthButtonStyle(depth: 4, depthColor: depth))
    }

    // MARK: - Subject card

    private var subjectCard: some View {
        let bg = typeColor(item.subject.subjectType).opacity(0.18)

        return VStack(spacing: 12) {
            HStack {
                Text(typeLabel(item.subject.subjectType))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(typeColor(item.subject.subjectType).opacity(0.2))
                    .foregroundStyle(typeColor(item.subject.subjectType))
                    .clipShape(Capsule())

                Spacer()
            }

            if let chars = item.subject.characters {
                Text(chars)
                    .font(.system(size: 80, weight: .regular))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .textSelection(.enabled)
            } else if let urlString = item.subject.characterImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
            } else {
                Text(item.subject.slug ?? "?")
                    .font(.system(size: 40, weight: .semibold))
            }

            Text("Level \(item.subject.level)")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func typeLabel(_ type: SubjectType) -> String {
        switch type {
        case .radical:        return "Radical"
        case .kanji:          return "Kanji"
        case .vocabulary:     return "Vocabulary"
        case .kanaVocabulary: return "Kana Vocab"
        }
    }

    private func typeColor(_ type: SubjectType) -> Color {
        switch type {
        case .radical:                     return Color("WKTeal")
        case .kanji:                       return Color("AccentPink")
        case .vocabulary, .kanaVocabulary: return Color("WKPlum")
        }
    }

    // MARK: - Multiple choice grid

    private var multipleChoiceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(item.choices, id: \.self) { choice in
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(
                        choice == item.correctChoice ? .success : .error
                    )
                    withAnimation(.easeOut(duration: 0.15)) {
                        onSelect(choice)
                    }
                } label: {
                    Text(choice)
                        .font(item.questionType == QuestionType.reading
                              ? .system(size: 22)
                              : .system(size: 19, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)
                        .foregroundStyle(choiceForeground(choice: choice))
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.horizontal, 8)
                        .background(choiceBackground(choice: choice))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ChoiceDepthButtonStyle(isAnswered: item.selectedChoice != nil))
                .disabled(item.selectedChoice != nil)
            }
        }
    }

    private func choiceBackground(choice: String) -> Color {
        guard let selected = item.selectedChoice else { return Color(.secondarySystemBackground) }
        if choice == item.correctChoice { return Color("WKGreen").opacity(0.28) }
        if choice == selected { return Color("WKRed").opacity(0.2) }
        return Color(.secondarySystemBackground)
    }

    private func choiceForeground(choice: String) -> Color {
        guard let selected = item.selectedChoice else { return .primary }
        if choice == item.correctChoice { return Color("WKGreen") }
        if choice == selected { return Color("WKRed") }
        return .secondary
    }

    // MARK: - Answer card

    private var answerCard: some View {
        let isVocab = item.subject.subjectType.isVocab

        return VStack(alignment: .leading, spacing: 16) {
            if !item.subject.meanings.isEmpty {
                labeledBlock(
                    title: "Meaning",
                    value: item.subject.meanings.joined(separator: ", "),
                    highlight: item.questionType == QuestionType.meaning,
                    jp: false
                )
            }

            if !item.subject.readings.isEmpty {
                Divider()
                labeledBlock(
                    title: "Reading",
                    value: item.subject.readings.joined(separator: ", "),
                    highlight: item.questionType == QuestionType.reading,
                    jp: true
                )
            }

            let components = orderedComponents(for: item.subject)
            if !components.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Composition")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(components, id: \.id) { comp in
                                VStack(spacing: 4) {
                                    Text(comp.characters ?? comp.slug ?? "?")
                                        .font(.system(size: 20))
                                        .foregroundStyle(typeColor(comp.subjectType))
                                    Text(comp.meanings.first ?? "")
                                        .font(.caption2.bold())
                                        .foregroundStyle(typeColor(comp.subjectType))
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 52)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(typeColor(comp.subjectType).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }

            if item.subject.subjectType == .kanji {
                let appearsIn = store.vocabularyContaining(kanjiId: item.subjectId)
                if !appearsIn.isEmpty {
                    Divider()
                    appearsInSection(appearsIn)
                }
            }

            if isVocab {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example Sentences")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, *), ExampleGeneratorService.isSupported {
                        InlineExampleCard(
                            subjectId: item.subjectId,
                            characters: item.subject.characters ?? item.subject.slug ?? "",
                            reading: item.subject.readings.first,
                            meaning: item.subject.meanings.first ?? "",
                            store: store
                        )
                    } else {
                        staticSentences(for: item.subjectId)
                    }
                    #else
                    staticSentences(for: item.subjectId)
                    #endif
                }
            }

            if !isVocab, let mnemonic = item.subject.meaningMnemonic, !mnemonic.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mnemonic")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(stripWKTags(mnemonic))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .padding(.top, 20)
        .padding([.horizontal, .bottom], 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // Composition kanji for a vocab word, ordered left-to-right as they appear in the word.
    // SwiftData fetches are unordered, so we sort by each kanji's position in the word's characters.
    // For non-vocab subjects (kanji showing radicals) the store's order is kept as-is.
    private func orderedComponents(for subject: CachedSubject) -> [CachedSubject] {
        let components = store.components(for: subject)
        guard subject.subjectType.isVocab, let word = subject.characters else { return components }

        func position(_ comp: CachedSubject) -> Int {
            guard let ch = comp.characters, let range = word.range(of: ch) else { return Int.max }
            return word.distance(from: word.startIndex, to: range.lowerBound)
        }
        return components.sorted { position($0) < position($1) }
    }

    @ViewBuilder
    private func appearsInSection(_ vocab: [CachedSubject]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appears In")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vocab, id: \.id) { v in
                        VStack(spacing: 3) {
                            Text(v.characters ?? v.slug ?? "")
                                .font(.system(size: 20))
                                .foregroundStyle(Color("WKPlum"))
                            Text(v.meanings.first ?? "")
                                .font(.caption2.bold())
                                .foregroundStyle(Color("WKPlum"))
                                .lineLimit(1)
                        }
                        .frame(minWidth: 52)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(Color("WKPlum").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labeledBlock(title: String, value: String, highlight: Bool, jp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(highlight ? Color.accentColor : .secondary)
                .textCase(.uppercase)
            Text(value)
                .font(jp ? .system(size: 24) : .system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(highlight ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight ? Color.accentColor.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: highlight ? 10 : 0))
    }

    @ViewBuilder
    private func staticSentences(for subjectId: Int) -> some View {
        let sentences = SentenceStore.shared.sentences(for: subjectId)
        if sentences.isEmpty {
            Text("No examples available.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        } else {
            ForEach(sentences.indices, id: \.self) { i in
                SentenceView(sentence: sentences[i])
            }
        }
    }
}
