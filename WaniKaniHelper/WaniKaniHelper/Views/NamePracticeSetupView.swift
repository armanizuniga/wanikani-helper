// Mode picker for Name Practice. Full names are the hardest, so the two halves are
// offered separately as a way in.
import SwiftUI

struct NamePracticeSetupView: View {
    let store: SubjectStore
    @State private var mode: NameMode = .surname
    @State private var startSession = false

    private let names = NameStore.shared

    var body: some View {
        List {
            Section {
                ForEach(NameMode.allCases) { m in
                    Button { mode = m } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text(m.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: mode == m ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(mode == m ? Color("AccentPink") : Color.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("What to practice")
            } footer: {
                Text("Japanese names use special readings that often differ from the ones WaniKani teaches, so they have to be learned separately. Nothing here is sent to WaniKani.")
            }

            Section {
                Button {
                    startSession = true
                } label: {
                    Text("Start \(NamePracticeService.sessionLength) Names")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("AccentPink"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .disabled(!names.isAvailable)
            }
        }
        .navigationTitle("Name Practice")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $startSession) {
            NamePracticeSessionView(mode: mode, store: store)
        }
    }
}
