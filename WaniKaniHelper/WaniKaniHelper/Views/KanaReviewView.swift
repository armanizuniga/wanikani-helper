// This view runs an interactive hiragana or katakana practice session.
// Displays one character at a time and accepts romanization input, grading answers and
// updating mastery levels via KanaReviewService. Shows a score summary on completion.
import SwiftUI
import UIKit

struct KanaReviewView: View {
    let store: KanaSRSStore
    let script: String

    @State private var service: KanaReviewService
    @Environment(\.dismiss) private var dismiss
    @State private var shakeAmount: CGFloat = 0
    @State private var cardOverlayOpacity: Double = 0
    @State private var cardOverlayColor: Color = .clear

    private var accentColor: Color { script == "hiragana" ? .blue : .orange }
    private var scriptLabel: String { script == "hiragana" ? "Hiragana" : "Katakana" }

    init(store: KanaSRSStore, script: String) {
        self.store = store
        self.script = script
        self._service = State(initialValue: KanaReviewService(store: store, script: script))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let entry = service.currentEntry {
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 20) {
                            characterCard(entry: entry)

                            Color.clear.frame(height: max(0, geo.size.height * 0.06))

                            choiceGrid

                            if service.isAnswered {
                                feedbackCard(entry: entry)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                        .animation(.easeOut(duration: 0.2), value: service.isAnswered)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
        }
        .onAppear { service.loadNext() }
    }

    // MARK: - Character card

    private func characterCard(entry: KanaSRSEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(cardOverlayColor)
                .opacity(cardOverlayOpacity)

            VStack(spacing: 16) {
                HStack {
                    Text(scriptLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentColor.opacity(0.18))
                        .foregroundStyle(accentColor)
                        .clipShape(Capsule())
                    Spacer()
                    masteryDots(level: entry.masteryLevel)
                }

                Text(entry.character)
                    .font(.system(size: 110, weight: .light))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .offset(x: shakeAmount)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func masteryDots(level: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < level ? accentColor : Color(.systemGray4))
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - 2×2 choice grid

    private var choiceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(service.choices, id: \.self) { choice in
                Button {
                    guard !service.isAnswered else { return }
                    UINotificationFeedbackGenerator().notificationOccurred(
                        choiceIsCorrect(choice) ? .success : .error
                    )
                    service.selectChoice(choice)
                    handleResult()
                } label: {
                    Text(choice)
                        .font(.system(size: 22, weight: .semibold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(choiceForeground(choice))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(.horizontal, 8)
                        .background(choiceBackground(choice))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(ChoiceDepthButtonStyle(isAnswered: service.isAnswered))
                .disabled(service.isAnswered)
            }
        }
    }

    private func choiceIsCorrect(_ choice: String) -> Bool {
        guard let entry = service.currentEntry else { return false }
        return store.romajiFor(character: entry.character).contains(choice)
    }

    private func choiceBackground(_ choice: String) -> Color {
        guard let selected = service.selectedChoice else {
            return Color(.secondarySystemBackground)
        }
        if choiceIsCorrect(choice) { return Color("WKGreen").opacity(0.25) }
        if choice == selected      { return Color("WKRed").opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private func choiceForeground(_ choice: String) -> Color {
        guard let selected = service.selectedChoice else { return .primary }
        if choiceIsCorrect(choice) { return Color("WKGreen") }
        if choice == selected      { return Color("WKRed") }
        return .secondary
    }

    // MARK: - Feedback card (incorrect only)

    private func feedbackCard(entry: KanaSRSEntry) -> some View {
        Group {
            switch service.answerResult {
            case .incorrect(let correct):
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("WKRed"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Incorrect")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color("WKRed"))
                            Text("Correct: \(correct)")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        masteryChangeView(entry: entry)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        service.advance()
                    } label: {
                        Text("Next")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(DepthButtonStyle(depth: 4, depthColor: accentColor.opacity(0.5)))
                }
                .padding(16)
                .background(Color("WKRed").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            default:
                EmptyView()
            }
        }
    }

    private func masteryChangeView(entry: KanaSRSEntry) -> some View {
        let level = entry.masteryLevel
        let label: String
        switch level {
        case 0: label = "New"
        case 1: label = "Learning"
        case 2: label = "Familiar"
        case 3: label = "Confident"
        case 4: label = "Strong"
        default: label = "Mastered"
        }
        return VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color("WKRed"))
                .textCase(.uppercase)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < level ? Color("WKRed") : Color("WKRed").opacity(0.2))
                        .frame(width: 14, height: 4)
                }
            }
        }
    }

    // MARK: - Answer handling

    private func handleResult() {
        switch service.answerResult {
        case .correct:
            flashCard(color: Color("WKGreen"))
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                service.advance()
            }
        case .incorrect:
            flashCard(color: Color("WKRed"))
            shake()
        case nil:
            break
        }
    }

    private func flashCard(color: Color) {
        cardOverlayColor = color
        withAnimation(.easeIn(duration: 0.1)) { cardOverlayOpacity = 0.22 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.35)) { cardOverlayOpacity = 0 }
        }
    }

    private func shake() {
        let d = 0.07
        withAnimation(.easeInOut(duration: d)) { shakeAmount = -12 }
        DispatchQueue.main.asyncAfter(deadline: .now() + d) {
            withAnimation(.easeInOut(duration: d)) { shakeAmount = 12 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + d * 2) {
            withAnimation(.easeInOut(duration: d)) { shakeAmount = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + d * 3) {
            withAnimation(.spring(duration: d)) { shakeAmount = 0 }
        }
    }
}
