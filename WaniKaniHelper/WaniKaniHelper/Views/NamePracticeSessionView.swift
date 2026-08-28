// The Name Practice quiz. Shows a name in kanji, four candidate readings, and on
// answering reveals the romaji plus a per-kanji breakdown of how the reading maps on.
import SwiftUI

struct NamePracticeSessionView: View {
    let mode: NameMode
    let store: SubjectStore

    @State private var service = NamePracticeService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if service.sessionComplete {
                completeView
            } else if let q = service.current {
                questionView(q)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if service.sessionComplete { dismiss() } else { service.endSessionEarly() }
                } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(service.answeredCount)/\(service.totalCount)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if service.queue.isEmpty { service.start(mode: mode) }
        }
    }

    // MARK: - Question

    private func questionView(_ q: NameQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                nameCard(q)
                if q.selected != nil { nextButton(q) }
                choiceGrid(q)
                if q.selected != nil { answerCard(q) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func nameCard(_ q: NameQuestion) -> some View {
        VStack(spacing: 8) {
            Text(mode == .full ? "Full Name" : (mode == .surname ? "Surname" : "Given Name"))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color("WKPlum"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color("WKPlum").opacity(0.15))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(q.kanji)
                .font(.system(size: 56, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.vertical, 18)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color("WKPlum").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func choiceGrid(_ q: NameQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            ForEach(q.choices, id: \.self) { choice in
                Button {
                    service.select(choice)
                } label: {
                    Text(choice)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(colorFor(choice: choice, q: q))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(backgroundFor(choice: choice, q: q))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(q.selected != nil)
            }
        }
    }

    private func colorFor(choice: String, q: NameQuestion) -> Color {
        guard q.selected != nil else { return .primary }
        if choice == q.reading { return Color("WKGreen") }
        return choice == q.selected ? .red : .secondary
    }

    private func backgroundFor(choice: String, q: NameQuestion) -> Color {
        guard q.selected != nil else { return Color(.systemGray6) }
        if choice == q.reading { return Color("WKGreen").opacity(0.2) }
        return choice == q.selected ? Color.red.opacity(0.15) : Color(.systemGray6)
    }

    private func nextButton(_ q: NameQuestion) -> some View {
        Button {
            service.advance()
        } label: {
            Text(service.currentIndex + 1 == service.totalCount ? "Finish" : "Next")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(q.isCorrect == true ? Color("WKGreen") : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reveal

    private func answerCard(_ q: NameQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(q.reading)
                    .font(.system(size: 22, weight: .bold))
                Text(q.romaji)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if !q.segments.isEmpty {
                Divider()
                Text("BREAKDOWN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                HStack(spacing: 8) {
                    ForEach(Array(q.segments.enumerated()), id: \.offset) { _, seg in
                        VStack(spacing: 3) {
                            Text(seg.kanji).font(.system(size: 26))
                            Text(seg.reading)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color("AccentPink"))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color("AccentPink").opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Spacer()
                }
            }

            // Where a kanji in the name is also a WaniKani subject, show what you already
            // know it as — usually a different reading, which is the point of the feature.
            let known = store.kanjiInSentence(q.kanji).filter { $0.isPassed }
            if !known.isEmpty {
                Divider()
                Text("YOU'VE LEARNED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                ForEach(known, id: \.id) { subject in
                    HStack(spacing: 8) {
                        Text(subject.characters ?? "")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(subject.meanings.first ?? "")
                                .font(.system(size: 14, weight: .medium))
                            if !subject.readings.isEmpty {
                                Text(subject.readings.prefix(3).joined(separator: "、"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("\(service.correctCount)/\(service.answeredCount)")
                .font(.system(size: 48, weight: .black, design: .rounded))
            Text("names read correctly")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("AccentPink"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}
