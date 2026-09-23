#if DEBUG
// Debug-only harness for re-checking the PromptLibrary grammar prompts against an on-device model
// (e.g. after an iOS update ships a new Apple model). Runs each prompt on a random vocab word the
// user has reached, with the same 5-try / word-check loop the example-sentence services use, and
// records every attempt so weak prompts stand out. Results can be shared as a plain-text report.
import SwiftUI
import UIKit

@Observable
@MainActor
final class PromptTestRunner {
    enum Backend: String, CaseIterable, Identifiable {
        case apple = "Apple AI"
        case qwen = "Qwen"
        var id: String { rawValue }
    }

    struct Attempt {
        let sentence: String?
        let error: String?
        let containsWord: Bool
        let seconds: Double
    }

    struct Result: Identifiable {
        let id = UUID()
        let prompt: GrammarPrompt
        let word: String
        let systemPrompt: String
        var attempts: [Attempt] = []
        var passed: Bool { attempts.last?.containsWord == true }
    }

    // Matches the retry cap in SentenceGeneratorService / ExampleGeneratorService.
    static let maxAttempts = 5

    private(set) var results: [Result] = []
    private(set) var isRunning = false
    private(set) var total = 0
    private(set) var backendName = ""
    private var task: Task<Void, Never>?

    func run(prompts: [GrammarPrompt], words: [String], backend: any AIBackend, name: String) {
        guard !isRunning, !words.isEmpty else { return }
        results = []
        total = prompts.count
        backendName = name
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true

        task = Task {
            for prompt in prompts {
                if Task.isCancelled { break }
                let word = words.randomElement() ?? ""
                let system = PromptLibrary.shared.compose(prompt, word: word)
                let index = results.count
                results.append(Result(prompt: prompt, word: word, systemPrompt: system))

                for _ in 0..<Self.maxAttempts {
                    if Task.isCancelled { break }
                    let start = Date()
                    do {
                        let output = try await backend.generate(
                            systemPrompt: system,
                            userPrompt: "Write a sentence using \(word)."
                        )
                        let hit = sentenceContainsWord(word, in: output.japanese)
                        results[index].attempts.append(Attempt(
                            sentence: output.japanese, error: nil, containsWord: hit,
                            seconds: Date().timeIntervalSince(start)
                        ))
                        if hit { break }
                    } catch {
                        results[index].attempts.append(Attempt(
                            sentence: nil, error: String(describing: error), containsWord: false,
                            seconds: Date().timeIntervalSince(start)
                        ))
                    }
                }
            }
            isRunning = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func stop() { task?.cancel() }

    // MARK: - Summary

    var passedCount: Int { results.filter(\.passed).count }
    var firstTryCount: Int { results.filter { $0.attempts.count == 1 && $0.passed }.count }
    var errorCount: Int { results.reduce(0) { $0 + $1.attempts.filter { $0.error != nil }.count } }

    var averageSeconds: Double {
        let all = results.flatMap(\.attempts)
        guard !all.isEmpty else { return 0 }
        return all.reduce(0) { $0 + $1.seconds } / Double(all.count)
    }

    var report: String {
        var out = "Prompt test — \(backendName) — \(Date().formatted(date: .abbreviated, time: .shortened))\n"
        out += "Passed \(passedCount)/\(results.count) · first try \(firstTryCount) · "
        out += "errors \(errorCount) · avg \(String(format: "%.1f", averageSeconds))s per attempt\n"

        let failed = results.filter { !$0.passed }
        if !failed.isEmpty {
            out += "\nFAILED\n"
            for r in failed { out += Self.describe(r) }
        }
        let retried = results.filter { $0.passed && $0.attempts.count > 1 }
        if !retried.isEmpty {
            out += "\nPASSED AFTER RETRIES\n"
            for r in retried { out += Self.describe(r) }
        }
        out += "\nFIRST TRY\n"
        for r in results where r.passed && r.attempts.count == 1 {
            out += "[N\(r.prompt.level)] \(r.prompt.point) — \(r.word): \(r.attempts[0].sentence ?? "")\n"
        }
        return out
    }

    private static func describe(_ r: Result) -> String {
        var out = "[N\(r.prompt.level)] \(r.prompt.point) — \(r.word)\n"
        for (i, a) in r.attempts.enumerated() {
            out += "  \(i + 1). \(a.sentence ?? "ERROR: \(a.error ?? "?")")\n"
        }
        return out
    }
}

struct PromptTestView: View {
    let store: SubjectStore
    let userLevel: Int

    @State private var runner = PromptTestRunner()
    @State private var backend: PromptTestRunner.Backend = .apple
    @State private var jlpt = 0   // 0 = all levels

    var body: some View {
        List {
            setupSection
            if !runner.results.isEmpty {
                summarySection
                resultsSection
            }
        }
        .navigationTitle("Prompt Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !runner.results.isEmpty && !runner.isRunning {
                ShareLink(item: runner.report) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onDisappear { runner.stop() }
    }

    // MARK: - Sections

    private var setupSection: some View {
        Section {
            Picker("Model", selection: $backend) {
                ForEach(PromptTestRunner.Backend.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(runner.isRunning)

            Picker("JLPT level", selection: $jlpt) {
                Text("All (\(PromptLibrary.allPrompts.count))").tag(0)
                ForEach([5, 4, 3, 2, 1], id: \.self) { level in
                    Text("N\(level) (\(PromptLibrary.allPrompts.filter { $0.level == level }.count))").tag(level)
                }
            }
            .disabled(runner.isRunning)

            if runner.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(runner.results.count), total: Double(max(runner.total, 1)))
                    Text("Prompt \(runner.results.count) of \(runner.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Stop", role: .destructive) { runner.stop() }
            } else {
                Button("Run Test") { start() }
                    .disabled(resolvedBackend == nil)
                if resolvedBackend == nil {
                    Text("\(backend.rawValue) isn't available on this device. For Qwen, download it in AI Model settings first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Each prompt gets a random vocab word from levels 1–\(userLevel) and up to \(PromptTestRunner.maxAttempts) tries, same as the app. Keep the app open while it runs.")
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Passed", value: "\(runner.passedCount) / \(runner.results.count)")
            LabeledContent("First try", value: "\(runner.firstTryCount)")
            LabeledContent("Errors", value: "\(runner.errorCount)")
            LabeledContent("Avg per attempt", value: String(format: "%.1fs", runner.averageSeconds))
        }
    }

    private var resultsSection: some View {
        Section("Results") {
            ForEach(runner.results.reversed()) { result in
                NavigationLink {
                    PromptTestDetailView(result: result)
                } label: {
                    HStack(spacing: 10) {
                        statusIcon(result)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("N\(result.prompt.level) · \(result.prompt.point)")
                                .font(.subheadline)
                                .lineLimit(1)
                            Text("\(result.word) · \(result.attempts.count) \(result.attempts.count == 1 ? "try" : "tries")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ result: PromptTestRunner.Result) -> some View {
        if result.passed && result.attempts.count == 1 {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if result.passed {
            Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(.orange)
        } else if result.attempts.count < PromptTestRunner.maxAttempts && runner.isRunning
                    && result.id == runner.results.last?.id {
            ProgressView()
        } else {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: - Running

    private var resolvedBackend: (any AIBackend)? {
        switch backend {
        case .qwen:
            return QwenBackend.shared.isAvailable ? QwenBackend.shared : nil
        case .apple:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), AppleFoundationBackend.shared.isAvailable {
                return AppleFoundationBackend.shared
            }
            #endif
            return nil
        }
    }

    private func start() {
        guard let model = resolvedBackend else { return }
        let prompts = jlpt == 0 ? PromptLibrary.allPrompts : PromptLibrary.allPrompts.filter { $0.level == jlpt }
        // Kanji vocabulary only — kana words make the contains-word check trivially easy.
        let words = (1...max(1, userLevel))
            .flatMap { store.subjects(level: $0) }
            .filter { $0.subjectType == .vocabulary }
            .compactMap(\.characters)
        runner.run(prompts: prompts, words: words, backend: model, name: backend.rawValue)
    }
}

private struct PromptTestDetailView: View {
    let result: PromptTestRunner.Result

    var body: some View {
        List {
            Section("Target word") {
                Text(result.word).font(.title2)
            }
            Section("Attempts") {
                ForEach(Array(result.attempts.enumerated()), id: \.offset) { i, attempt in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Try \(i + 1)").font(.caption.bold())
                            Spacer()
                            Text(String(format: "%.1fs", attempt.seconds))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: attempt.containsWord ? "checkmark" : "xmark")
                                .foregroundStyle(attempt.containsWord ? .green : .red)
                        }
                        if let sentence = attempt.sentence {
                            Text(sentence).textSelection(.enabled)
                        } else {
                            Text(attempt.error ?? "Unknown error")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            Section("System prompt") {
                Text(result.systemPrompt)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(result.prompt.point)
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
