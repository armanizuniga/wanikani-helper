// Runs a local Kanji Review practice session: multiple-choice meaning/reading questions over the
// kanji the user picked by SRS category. Reuses ReviewCardView for the card UI. Nothing is
// submitted to WaniKani — this is pure self-practice.
import SwiftUI

struct KanjiReviewSessionView: View {
    let service: KanjiReviewService
    let store: SubjectStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if service.sessionComplete {
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
                if !service.sessionComplete && !service.queue.isEmpty {
                    Text("\(service.completedCount)/\(service.totalCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize()
                }
            }
        }
    }

    // MARK: - Review mode

    @ViewBuilder
    private func reviewView(item: ReviewItem) -> some View {
        let completed = Double(service.completedCount)
        let total = Double(max(service.totalCount, 1))

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

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No kanji to review")
                .font(.title3.bold())
        }
    }

    // MARK: - Session complete

    private var completeView: some View {
        let byKanji      = Dictionary(grouping: service.queue.filter { $0.answered }, by: { $0.subjectId })
        let attempted    = byKanji.count
        let correctCount = byKanji.filter { $0.value.allSatisfy { $0.choiceWasCorrect == true } }.count
        let missedCount  = byKanji.filter { $0.value.contains { $0.choiceWasCorrect == false } }.count
        let pct          = attempted > 0 ? Int(Double(correctCount) / Double(attempted) * 100) : 0

        return VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 6) {
                    Text("Practice Complete!")
                        .font(.title.bold())
                    Text("\(service.completedCount) of \(service.totalCount) kanji")
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
}
