// This view runs a lesson session for new WaniKani items. Steps through radicals, kanji, and
// vocabulary in order, showing each subject's characters, meanings, readings, composition,
// and — for vocabulary — an AI-generated example sentence or static fallback sentences.
import SwiftUI
import UIKit

struct LessonSessionView: View {
    let store: SubjectStore
    @State private var service: LessonService
    @Environment(\.dismiss) private var dismiss

    init(store: SubjectStore) {
        self.store = store
        self._service = State(initialValue: LessonService(store: store))
    }

    var body: some View {
        Group {
            if service.isLoading {
                loadingView
            } else if service.sessionComplete {
                completeView
            } else if service.queue.isEmpty {
                emptyView
            } else if let item = service.current {
                lessonView(item: item)
            }
        }
        .navigationTitle("Lessons")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !service.isLoading && !service.sessionComplete && !service.queue.isEmpty {
                    Text("\(service.currentIndex + 1)/\(service.totalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await service.loadQueue() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading lessons…")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color("WKTeal"))
            Text("No lessons available")
                .font(.title3.bold())
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color("WKGreen"))

                VStack(spacing: 6) {
                    Text("Lessons Complete!")
                        .font(.title.bold())
                    Text("\(service.totalCount) lessons started")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Lesson view

    @ViewBuilder
    private func lessonView(item: LessonItem) -> some View {
        VStack(spacing: 0) {
            lessonProgressBar

            ScrollView {
                VStack(spacing: 16) {
                    subjectCard(item: item)
                    infoCard(item: item)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .bottom) {
            let isLast = service.isOnLastItem
            let btnColor: Color = isLast ? Color("WKTeal") : Color("WKGreen")
            let depthColor: Color = isLast ? Color("WKTealDeep") : Color(red: 0.05, green: 0.45, blue: 0.18)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                service.advance()
            } label: {
                Text(isLast ? "Complete \(service.totalCount) Lessons" : "Next")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(btnColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(DepthButtonStyle(depth: 4, depthColor: depthColor))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Progress bar

    private var lessonProgressBar: some View {
        let completed = Double(service.currentIndex)
        let total = Double(max(service.totalCount, 1))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(.systemGray5))
                Rectangle()
                    .fill(Color("WKTeal"))
                    .frame(width: geo.size.width * (completed / total))
                    .animation(.easeOut(duration: 0.35), value: completed)
            }
        }
        .frame(height: 5)
    }

    // MARK: - Subject card

    private func subjectCard(item: LessonItem) -> some View {
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

    // MARK: - Info card

    private func infoCard(item: LessonItem) -> some View {
        let isVocab = item.subject.subjectType.isVocab

        return VStack(alignment: .leading, spacing: 16) {
            if !item.subject.meanings.isEmpty {
                infoBlock(title: "Meaning",
                          value: item.subject.meanings.joined(separator: ", "),
                          jp: false)
            }

            if !item.subject.readings.isEmpty {
                Divider()
                infoBlock(title: "Reading",
                          value: item.subject.readings.joined(separator: ", "),
                          jp: true)
            }

            let components = store.components(for: item.subject)
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
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    private func infoBlock(title: String, value: String, jp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(jp ? .system(size: 24) : .system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

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
}
