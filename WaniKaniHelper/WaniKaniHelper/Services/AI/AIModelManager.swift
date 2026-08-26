// Coordinates backend selection, Qwen model download/load lifecycle, and backend switching.
// Persists the active backend choice to UserDefaults so it survives force quits.
// QwenBackend is preferred when downloaded; AppleFoundationBackend is the automatic fallback on iOS 26+.
import Foundation
import Observation

@Observable
@MainActor
final class AIModelManager {
    static let shared = AIModelManager()

    enum ActiveBackend: String {
        case apple, qwen, bundled, claude
    }

    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)  // 0.0 – 1.0
        case downloaded
        case failed(String)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.notDownloaded, .notDownloaded), (.downloaded, .downloaded): return true
            case (.downloading(let a), .downloading(let b)):                  return a == b
            case (.failed(let a),      .failed(let b)):                       return a == b
            default: return false
            }
        }
    }

    private(set) var downloadState: DownloadState
    private var downloadTask: Task<Void, Never>?

    // Stored so @Observable tracks it and SwiftUI views re-render automatically.
    var activeBackend: ActiveBackend = .apple {
        didSet { UserDefaults.standard.set(activeBackend.rawValue, forKey: "aiBackend") }
    }

    private init() {
        downloadState = QwenBackend.isDownloaded ? .downloaded : .notDownloaded
        let raw = UserDefaults.standard.string(forKey: "aiBackend") ?? (QwenBackend.isDownloaded ? "qwen" : "apple")
        activeBackend = ActiveBackend(rawValue: raw) ?? .apple

        // Re-load model into memory if it was downloaded in a previous session.
        if QwenBackend.isDownloaded {
            Task { await QwenBackend.shared.loadIfDownloaded() }
        }
    }

    // MARK: - Backend selection

    var isAnyBackendAvailable: Bool {
        if BundledSentenceStore.shared.isAvailable { return true }
        if ClaudeBackend.shared.isAvailable { return true }
        if QwenBackend.shared.isAvailable { return true }
        if downloadState == .downloaded { return true }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return AppleFoundationBackend.shared.isAvailable }
        #endif
        return false
    }

    var currentBackend: any AIBackend {
        if activeBackend == .claude && ClaudeBackend.shared.isAvailable {
            return ClaudeBackend.shared
        }
        if activeBackend == .qwen && QwenBackend.shared.isAvailable {
            return QwenBackend.shared
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AppleFoundationBackend.shared.isAvailable {
            return AppleFoundationBackend.shared
        }
        #endif
        return QwenBackend.shared  // will throw .notAvailable
    }

    var activeBackendName: String {
        switch activeBackend {
        case .claude where ClaudeBackend.shared.isAvailable: return "Claude"
        case .bundled: return "Pre-generated"
        case .qwen where downloadState == .downloaded: return "Qwen2.5-3B"
        case .apple:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), AppleFoundationBackend.shared.isAvailable { return "Apple AI" }
            #endif
            return "None"
        default: return "None"
        }
    }

    // MARK: - Download

    func startDownload() {
        guard downloadState != .downloaded else { return }
        downloadTask?.cancel()
        downloadTask = Task { await performDownload() }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadState = .notDownloaded
    }

    func switchToApple() { activeBackend = .apple }

    func switchToBundled() { activeBackend = .bundled }

    func switchToClaude() {
        guard ClaudeBackend.shared.isAvailable else { return }
        activeBackend = .claude
    }

    func switchToQwen() {
        guard QwenBackend.isDownloaded else { return }
        activeBackend = .qwen
        Task { await QwenBackend.shared.loadIfDownloaded() }
    }

    func deleteQwenModel() {
        try? FileManager.default.removeItem(at: QwenBackend.cacheURL)
        downloadState = .notDownloaded
        activeBackend = .apple
    }

    // MARK: - Private

    // MLXLLM's loadContainer handles both downloading from HuggingFace and loading into memory.
    // If the model is already cached, it skips the network entirely.
    private func performDownload() async {
        downloadState = .downloading(progress: 0)
        do {
            try await QwenBackend.shared.downloadAndLoad { [weak self] progress in
                self?.downloadState = .downloading(progress: progress)
            }
            downloadState = .downloaded
            activeBackend = .qwen
        } catch {
            guard !Task.isCancelled else { return }
            downloadState = .failed("Download failed. Check your connection and try again.")
        }
    }
}
