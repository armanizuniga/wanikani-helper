// Settings view for managing the on-device AI model. Lets the user download Qwen2.5-3B,
// track download progress, switch between backends, or delete the model to free space.
import SwiftUI

struct AIModelSetupView: View {
    private var manager: AIModelManager { AIModelManager.shared }

    @State private var claudeKeyInput = ""
    @State private var hasClaudeKey = ClaudeBackend.shared.isAvailable

    var body: some View {
        List {
            activeBackendSection
            bundledSection
            qwenSection
            claudeSection

            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), AppleFoundationBackend.shared.isAvailable {
                appleSection
            }
            #endif
        }
        .navigationTitle("AI Model")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Active backend

    private var activeBackendSection: some View {
        Section {
            HStack {
                Label("Active Backend", systemImage: "cpu")
                Spacer()
                Text(manager.activeBackendName)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("The active backend is used for Reading Practice sentences and inline example sentences.")
        }
    }

    // MARK: - Bundled sentences section

    private var bundledSection: some View {
        Section {
            HStack {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(.purple)
                Text("Pre-generated Sentences")
                Spacer()
                if manager.activeBackend == .bundled {
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            if manager.activeBackend != .bundled {
                Button("Use Pre-generated Sentences") {
                    manager.switchToBundled()
                }
            }
        } header: {
            Text("Pre-generated (Bundled)")
        } footer: {
            Text("Example sentences for 6,000+ vocabulary words generated offline and bundled with the app. No download required. Tap the regenerate button to cycle through available sentences.")
        }
    }

    // MARK: - Qwen section

    @ViewBuilder
    private var qwenSection: some View {
        Section {
            switch manager.downloadState {
            case .notDownloaded:
                notDownloadedRow

            case .downloading(let progress):
                downloadingRow(progress: progress)

            case .downloaded:
                downloadedRow

            case .failed(let message):
                failedRow(message: message)
            }
        } header: {
            Text("Qwen2.5-3B (On-Device)")
        } footer: {
            switch manager.downloadState {
            case .notDownloaded, .failed:
                Text("Downloads the Qwen2.5-3B-Instruct model (~1.8 GB). Use Wi-Fi. The model runs entirely on your device — no data is sent to a server.")
            default:
                EmptyView()
            }
        }
    }

    private var notDownloadedRow: some View {
        Button {
            manager.startDownload()
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download AI Model")
                        .foregroundStyle(.primary)
                    Text("~1.8 GB · Recommended on Wi-Fi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func downloadingRow(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Downloading…")
                    .font(.system(size: 15))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(.blue)
            Button("Cancel", role: .destructive) {
                manager.cancelDownload()
            }
            .font(.system(size: 14))
        }
        .padding(.vertical, 4)
    }

    private var downloadedRow: some View {
        Group {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Qwen2.5-3B Downloaded")
                Spacer()
                if manager.activeBackend == .qwen {
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            if manager.activeBackend != .qwen {
                Button("Use Qwen2.5-3B") {
                    manager.switchToQwen()
                }
            }

            Button("Delete Model", role: .destructive) {
                manager.deleteQwenModel()
            }
        }
    }

    private func failedRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Download Failed")
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                manager.startDownload()
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Claude section

    @ViewBuilder
    private var claudeSection: some View {
        Section {
            if hasClaudeKey {
                HStack {
                    Image(systemName: "cloud")
                        .foregroundStyle(.orange)
                    Text("Claude")
                    Spacer()
                    if manager.activeBackend == .claude {
                        Text("Active")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }

                if manager.activeBackend != .claude {
                    Button("Use Claude") {
                        manager.switchToClaude()
                    }
                }

                Button("Remove API Key", role: .destructive) {
                    ClaudeBackend.deleteKey()
                    hasClaudeKey = false
                    claudeKeyInput = ""
                    if manager.activeBackend == .claude {
                        manager.switchToApple()
                    }
                }
            } else {
                SecureField("sk-ant-…", text: $claudeKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Save API Key") {
                    ClaudeBackend.saveKey(claudeKeyInput)
                    hasClaudeKey = ClaudeBackend.shared.isAvailable
                    if hasClaudeKey {
                        claudeKeyInput = ""
                        manager.switchToClaude()
                    }
                }
                .disabled(claudeKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Claude (Cloud)")
        } footer: {
            Text("Generates sentences with Anthropic's Claude using your own API key. Sentences are sent to Anthropic's servers; the key is stored only in your device's Keychain. Get a key at console.anthropic.com.")
        }
    }

    // MARK: - Apple section

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private var appleSection: some View {
        Section("Apple On-Device AI") {
            HStack {
                Image(systemName: "apple.logo")
                    .foregroundStyle(.primary)
                Text("Apple Foundation Models")
                Spacer()
                if manager.activeBackend == .apple {
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            if manager.activeBackend != .apple {
                Button("Switch to Apple AI") {
                    manager.switchToApple()
                }
            }
        }
    }
    #endif
}
