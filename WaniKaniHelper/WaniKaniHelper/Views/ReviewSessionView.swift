// This view runs a WaniKani review session with multiple-choice questions for meaning and reading.
// Shows a results screen on completion with correct/incorrect counts, and displays AI-generated
// example sentences for vocabulary items.
import SwiftUI
import UIKit

struct ReviewSessionView: View {
    let store: SubjectStore
    @State private var service: ReviewService
    @Environment(\.dismiss) private var dismiss

    init(store: SubjectStore) {
        self.store = store
        self._service = State(initialValue: ReviewService(store: store))
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
                reviewView(item: item)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if service.sessionComplete {
                        dismiss()
                    } else {
                        service.endSessionEarly()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !service.isLoading && !service.sessionComplete && !service.queue.isEmpty {
                    HStack(spacing: 8) {
                        if ReviewSettings.easyMode {
                            Text("EASY")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color("WKTeal"))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color("WKTeal").opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text("\(service.completedAssignmentCount)/\(service.totalAssignmentCount)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize()
                    }
                }
            }
        }
        .task { await service.loadQueue() }
        .overlay(alignment: .top) {
            if let warning = service.networkWarning {
                OfflineBanner(message: warning) { service.clearNetworkWarning() }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: service.networkWarning)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading reviews…")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            if service.networkWarning != nil {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Couldn't load reviews")
                    .font(.title3.bold())
                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("No reviews available")
                    .font(.title3.bold())
            }
        }
    }

    // MARK: - Session complete

    private var completeView: some View {
        let byAssignment = Dictionary(grouping: service.queue.filter { $0.answered }, by: { $0.assignmentId })
        let attempted    = byAssignment.count
        let correctCount = byAssignment.filter { $0.value.allSatisfy { $0.choiceWasCorrect == true } }.count
        let missedCount  = byAssignment.filter { $0.value.contains { $0.choiceWasCorrect == false } }.count
        let pct          = attempted > 0 ? Int(Double(correctCount) / Double(attempted) * 100) : 0

        return VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 6) {
                    Text("Session Complete!")
                        .font(.title.bold())
                    Text("\(service.completedAssignmentCount) of \(service.totalAssignmentCount) reviewed")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    statCell(value: "\(correctCount)", label: "Correct")
                    Divider().frame(height: 48)
                    statCell(value: "\(missedCount)", label: "Missed")
                    Divider().frame(height: 48)
                    statCell(value: "\(pct)%", label: "Accuracy")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Review mode

    @ViewBuilder
    private func reviewView(item: ReviewItem) -> some View {
        let completed = Double(service.completedAssignmentCount)
        let total = Double(max(service.totalAssignmentCount, 1))

        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.systemGray5))
                    Rectangle()
                        .fill(Color("WKGreen"))
                        .frame(width: geo.size.width * (completed / total))
                        .animation(.easeOut(duration: 0.35), value: completed)
                }
            }
            .frame(height: 4)

            ReviewCardView(
                item: item,
                store: store,
                onSelect: { service.selectChoice($0) },
                onConfirm: { service.confirmAndAdvance() }
            )
        }
    }
}

// MARK: - 3D press button styles

struct DepthButtonStyle: ButtonStyle {
    var depth: CGFloat = 4
    var depthColor: Color = .black.opacity(0.2)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(
                color: depthColor.opacity(configuration.isPressed ? 0 : 1),
                radius: 0,
                x: 0,
                y: configuration.isPressed ? 0 : depth
            )
            .offset(y: configuration.isPressed ? depth : 0)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

// Used for choice buttons — depth rectangle sits behind the clipped face.
// When answered, depth is removed entirely so semi-transparent result
// backgrounds don't show the backing rectangle through as a ghost.
struct ChoiceDepthButtonStyle: ButtonStyle {
    var isAnswered: Bool = false
    var depth: CGFloat = 5
    var depthColor: Color = Color(.systemGray3)
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        if isAnswered {
            configuration.label
        } else {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(depthColor)
                        .opacity(configuration.isPressed ? 0 : 1)
                        .offset(y: depth)
                )
                .offset(y: configuration.isPressed ? depth : 0)
                .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
        }
    }
}

// MARK: - Sentence view

struct SentenceView: View {
    let sentence: ExampleSentence
    @State private var showTranslation = false
    @State private var showQuestionAnswer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sentence.japanese)
                .font(.system(size: 17))

            if sentence.english != nil {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showTranslation.toggle() }
                    } label: {
                        Label(showTranslation ? "Hide" : "Translation",
                              systemImage: showTranslation ? "eye.slash" : "eye")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    if showTranslation {
                        Text(sentence.english!)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
            }

            if let question = sentence.question {
                Text(question)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showQuestionAnswer.toggle() }
                    } label: {
                        Label(showQuestionAnswer ? "Hide" : "Answer",
                              systemImage: showQuestionAnswer ? "eye.slash" : "eye")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    if showQuestionAnswer, let answer = sentence.questionEnglish {
                        Text(answer)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Helpers

func stripWKTags(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "</?[a-z]+>") else { return text }
    return regex.stringByReplacingMatches(
        in: text, range: NSRange(text.startIndex..., in: text), withTemplate: ""
    )
}
