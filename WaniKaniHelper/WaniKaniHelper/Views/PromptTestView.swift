#if DEBUG
// Debug-only harness for re-checking the PromptLibrary grammar prompts against the AI models
// (e.g. after an iOS update ships a new Apple model). Runs each prompt on a random vocab word the
// user has reached with the same selection the app uses — up to 5 tries, keep the sentence with
// the fewest unknown (below-Master) kanji — and records every attempt. For the Apple models it can
// also switch the known-words tool off and change how many words Apple Cloud gets, so their value
// can be measured. Results can be shared as a plain-text report.
import SwiftUI
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

@Observable
@MainActor
final class PromptTestRunner {
    enum Backend: String, CaseIterable, Identifiable {
        case apple = "Apple"
        case appleCloud = "Apple Cloud"
        case qwen = "Qwen"
        var id: String { rawValue }
        var usesTool: Bool { self != .qwen }
    }

    struct Attempt {
        let sentence: String?
        let error: String?
        let containsWord: Bool
        let unknownKanji: [Character]
        let toolCalls: Int
        let usedFallback: Bool   // Apple Cloud answered on-device instead
        let seconds: Double
    }

    struct Result: Identifiable {
        let id = UUID()
        let prompt: GrammarPrompt
        let word: String
        let systemPrompt: String
        var attempts: [Attempt] = []
        var chosenIndex: Int?     // the attempt the app would show
        var isFinished = false

        var passed: Bool { chosenIndex != nil }
        var chosen: Attempt? { chosenIndex.map { attempts[$0] } }
        var allKnown: Bool { chosen?.unknownKanji.isEmpty == true }
    }

    // Matches the retry cap in SentenceGeneratorService / ExampleGeneratorService.
    static let maxAttempts = 5

    private(set) var results: [Result] = []
    private(set) var isRunning = false
    private(set) var total = 0
    private(set) var configLabel = ""
    private(set) var toolWasEnabled = false
    private(set) var wasCloud = false
    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - fallbackReason: read after each attempt; non-nil means Apple Cloud fell back to on-device.
    ///   - setUp / tearDown: apply the run's tool settings to the backend, and put them back after.
    func run(
        prompts: [GrammarPrompt], words: [String], backend: any AIBackend,
        configLabel: String, toolEnabled: Bool, isCloud: Bool,
        fallbackReason: @escaping () -> String?,
        setUp: () -> Void, tearDown: @escaping () -> Void
    ) {
        guard !isRunning, !words.isEmpty else { return }
        results = []
        total = prompts.count
        self.configLabel = configLabel
        toolWasEnabled = toolEnabled
        wasCloud = isCloud
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        setUp()

        task = Task {
            for prompt in prompts {
                if Task.isCancelled { break }
                let word = words.randomElement() ?? ""
                let system = PromptLibrary.shared.compose(prompt, word: word)
                let index = results.count
                results.append(Result(prompt: prompt, word: word, systemPrompt: system))
                await runAttempts(index: index, word: word, system: system, backend: backend, fallbackReason: fallbackReason)
                results[index].isFinished = true
            }
            tearDown()
            isRunning = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // Mirrors bestKnownKanjiSentence, but records every attempt instead of only the winner.
    private func runAttempts(index: Int, word: String, system: String, backend: any AIBackend, fallbackReason: () -> String?) async {
        var bestUnknown = Int.max
        var triesSinceBest = 0

        for _ in 0..<Self.maxAttempts {
            if Task.isCancelled { return }
            resetToolCalls()
            let start = Date()
            let attempt: Attempt
            do {
                let output = try await backend.generate(systemPrompt: system, userPrompt: "Write a sentence using \(word).")
                attempt = Attempt(
                    sentence: output.japanese, error: nil,
                    containsWord: sentenceContainsWord(word, in: output.japanese),
                    unknownKanji: KnownKanji.unknown(in: output.japanese, target: word),
                    toolCalls: toolCalls(), usedFallback: fallbackReason() != nil,
                    seconds: Date().timeIntervalSince(start)
                )
            } catch {
                attempt = Attempt(
                    sentence: nil, error: String(describing: error), containsWord: false,
                    unknownKanji: [], toolCalls: toolCalls(), usedFallback: fallbackReason() != nil,
                    seconds: Date().timeIntervalSince(start)
                )
            }
            results[index].attempts.append(attempt)

            if attempt.containsWord, attempt.unknownKanji.count < bestUnknown {
                bestUnknown = attempt.unknownKanji.count
                results[index].chosenIndex = results[index].attempts.count - 1
                if bestUnknown == 0 { return }
            }
            if results[index].chosenIndex != nil {
                triesSinceBest += 1
                if triesSinceBest > KnownKanji.improvementTries { return }
            }
        }
    }

    private func resetToolCalls() {
        #if canImport(FoundationModels)
        KnownVocabularyTool.resetCallCount()
        #endif
    }

    private func toolCalls() -> Int {
        #if canImport(FoundationModels)
        return KnownVocabularyTool.callsSinceReset
        #else
        return 0
        #endif
    }

    func stop() { task?.cancel() }

    // MARK: - Summary

    private var allAttempts: [Attempt] { results.flatMap(\.attempts) }

    var passedCount: Int { results.filter(\.passed).count }
    var allKnownCount: Int { results.filter(\.allKnown).count }
    var errorCount: Int { allAttempts.filter { $0.error != nil }.count }
    var toolUsedCount: Int { allAttempts.filter { $0.toolCalls > 0 }.count }
    var fallbackCount: Int { allAttempts.filter(\.usedFallback).count }

    var averageUnknownKanji: Double {
        let chosen = results.compactMap(\.chosen)
        guard !chosen.isEmpty else { return 0 }
        return Double(chosen.reduce(0) { $0 + $1.unknownKanji.count }) / Double(chosen.count)
    }

    var averageTries: Double {
        guard !results.isEmpty else { return 0 }
        return Double(allAttempts.count) / Double(results.count)
    }

    var averageSeconds: Double {
        guard !allAttempts.isEmpty else { return 0 }
        return allAttempts.reduce(0) { $0 + $1.seconds } / Double(allAttempts.count)
    }

    static func percent(_ part: Int, of whole: Int) -> String {
        whole == 0 ? "–" : "\(Int((Double(part) / Double(whole) * 100).rounded()))%"
    }

    var report: String {
        var out = "Prompt test — \(configLabel) — \(Date().formatted(date: .abbreviated, time: .shortened))\n"
        out += "Word included \(passedCount)/\(results.count) · "
        out += "only known kanji \(allKnownCount)/\(passedCount) (\(Self.percent(allKnownCount, of: passedCount))) · "
        out += "avg unknown kanji \(String(format: "%.2f", averageUnknownKanji))\n"
        out += "Avg tries \(String(format: "%.1f", averageTries)) · avg \(String(format: "%.1f", averageSeconds))s per try · errors \(errorCount)"
        if toolWasEnabled {
            out += " · tool used \(toolUsedCount)/\(allAttempts.count) tries"
        }
        if wasCloud {
            out += " · cloud fallbacks \(fallbackCount)"
        }
        out += "\n"

        let failed = results.filter { !$0.passed }
        if !failed.isEmpty {
            out += "\nWORD MISSING\n"
            for r in failed { out += Self.describe(r) }
        }
        let unknown = results.filter { $0.passed && !$0.allKnown }
        if !unknown.isEmpty {
            out += "\nUNKNOWN KANJI IN CHOSEN SENTENCE\n"
            for r in unknown { out += Self.describe(r) }
        }
        out += "\nALL KNOWN\n"
        for r in results where r.allKnown {
            out += "[N\(r.prompt.level)] \(r.prompt.point) — \(r.word): \(r.chosen?.sentence ?? "")\n"
        }
        return out
    }

    private static func describe(_ r: Result) -> String {
        var out = "[N\(r.prompt.level)] \(r.prompt.point) — \(r.word)\n"
        for (i, a) in r.attempts.enumerated() {
            let marker = i == r.chosenIndex ? "→" : " "
            var line = a.sentence ?? "ERROR: \(a.error ?? "?")"
            if !a.unknownKanji.isEmpty { line += "  [unknown: \(String(a.unknownKanji))]" }
            if a.toolCalls > 0 { line += "  [tool ×\(a.toolCalls)]" }
            if a.usedFallback { line += "  [on-device fallback]" }
            out += " \(marker)\(i + 1). \(line)\n"
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
    @State private var toolEnabled = true
    @State private var cloudVocabLimit = 200

    private static let cloudVocabOptions = [100, 200, 500]

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

            Picker("JLPT level", selection: $jlpt) {
                Text("All (\(PromptLibrary.allPrompts.count))").tag(0)
                ForEach([5, 4, 3, 2, 1], id: \.self) { level in
                    Text("N\(level) (\(PromptLibrary.allPrompts.filter { $0.level == level }.count))").tag(level)
                }
            }

            if backend.usesTool {
                Toggle("Known-words tool", isOn: $toolEnabled)
            }
            if backend == .appleCloud && toolEnabled {
                Picker("Words per tool call", selection: $cloudVocabLimit) {
                    ForEach(Self.cloudVocabOptions, id: \.self) { Text("\($0)").tag($0) }
                }
            }

            if runner.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(runner.results.count), total: Double(max(runner.total, 1)))
                    Text("Prompt \(runner.results.count) of \(runner.total) · \(runner.configLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Stop", role: .destructive) { runner.stop() }
            } else {
                Button("Run Test") { start() }
                    .disabled(resolvedBackend == nil)
                if resolvedBackend == nil {
                    Text(unavailableText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Each prompt gets a random vocab word from levels 1–\(userLevel) and up to \(PromptTestRunner.maxAttempts) tries, keeping the sentence with the fewest kanji below Master — same as the app. Known kanji: \(KnownKanji.all.count). Known vocab: \(KnownKanji.vocabulary.count). Keep the app open while it runs.")
        }
        .disabled(runner.isRunning)
    }

    private var summarySection: some View {
        Section("Summary · \(runner.configLabel)") {
            LabeledContent("Word included", value: "\(runner.passedCount) / \(runner.results.count)")
            LabeledContent("Only known kanji",
                           value: "\(runner.allKnownCount) / \(runner.passedCount) (\(PromptTestRunner.percent(runner.allKnownCount, of: runner.passedCount)))")
            LabeledContent("Avg unknown kanji", value: String(format: "%.2f", runner.averageUnknownKanji))
            LabeledContent("Avg tries", value: String(format: "%.1f", runner.averageTries))
            LabeledContent("Avg per try", value: String(format: "%.1fs", runner.averageSeconds))
            LabeledContent("Errors", value: "\(runner.errorCount)")
            if runner.toolWasEnabled {
                LabeledContent("Tool used", value: "\(runner.toolUsedCount) tries")
            }
            if runner.wasCloud {
                LabeledContent("Cloud fallbacks", value: "\(runner.fallbackCount)")
            }
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
                            Text(resultSubtitle(result))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func resultSubtitle(_ result: PromptTestRunner.Result) -> String {
        var text = "\(result.word) · \(result.attempts.count) \(result.attempts.count == 1 ? "try" : "tries")"
        if let unknown = result.chosen?.unknownKanji, !unknown.isEmpty {
            text += " · unknown \(String(unknown))"
        }
        return text
    }

    // Green: every kanji known. Gold: word included but some kanji below Master. Red: no usable sentence.
    @ViewBuilder
    private func statusIcon(_ result: PromptTestRunner.Result) -> some View {
        if !result.isFinished {
            ProgressView()
        } else if result.allKnown {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if result.passed {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color("WKGold"))
        } else {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: - Running

    private var unavailableText: String {
        switch backend {
        case .apple:      return "Apple's on-device model isn't available on this device."
        case .appleCloud: return "Apple Cloud needs the Private Cloud Compute entitlement (see AppleCloud.isEntitled), iOS 27, and a device that supports Apple Intelligence."
        case .qwen:       return "Qwen isn't loaded. Download it in AI Model settings first."
        }
    }

    private var resolvedBackend: (any AIBackend)? {
        switch backend {
        case .qwen:
            return QwenBackend.shared.isAvailable ? QwenBackend.shared : nil
        case .apple:
            #if canImport(FoundationModels)
            if AppleFoundationBackend.shared.isAvailable { return AppleFoundationBackend.shared }
            #endif
            return nil
        case .appleCloud:
            #if canImport(FoundationModels)
            // Require the cloud model itself — the backend's on-device fallback would make the
            // run measure the wrong model.
            if #available(iOS 27.0, *), AppleCloud.isReady { return AppleFoundationBackend.cloud }
            #endif
            return nil
        }
    }

    private var configLabel: String {
        var label = backend.rawValue
        if backend.usesTool {
            label += toolEnabled ? " · tool on" : " · tool off"
        }
        if backend == .appleCloud && toolEnabled {
            label += " · \(cloudVocabLimit) words"
        }
        return label
    }

    private func start() {
        guard let model = resolvedBackend else { return }
        let prompts = jlpt == 0 ? PromptLibrary.allPrompts : PromptLibrary.allPrompts.filter { $0.level == jlpt }
        // Kanji vocabulary only — kana words make the contains-word check trivially easy.
        let words = (1...max(1, userLevel))
            .flatMap { store.subjects(level: $0) }
            .filter { $0.subjectType == .vocabulary }
            .compactMap(\.characters)

        #if canImport(FoundationModels)
        let apple: AppleFoundationBackend? = switch backend {
        case .apple:      AppleFoundationBackend.shared
        case .appleCloud: AppleFoundationBackend.cloud
        case .qwen:       nil
        }
        let savedTool = apple?.toolEnabled ?? true
        let savedLimit = apple?.cloudVocabLimit ?? 200
        let tool = toolEnabled, limit = cloudVocabLimit

        runner.run(
            prompts: prompts, words: words, backend: model,
            configLabel: configLabel, toolEnabled: backend.usesTool && tool, isCloud: backend == .appleCloud,
            fallbackReason: { backend == .appleCloud ? AppleFoundationBackend.cloud.lastCloudFallbackReason : nil },
            setUp: {
                apple?.toolEnabled = tool
                apple?.cloudVocabLimit = limit
            },
            tearDown: {
                apple?.toolEnabled = savedTool
                apple?.cloudVocabLimit = savedLimit
            }
        )
        #else
        runner.run(
            prompts: prompts, words: words, backend: model,
            configLabel: configLabel, toolEnabled: false, isCloud: false,
            fallbackReason: { nil }, setUp: {}, tearDown: {}
        )
        #endif
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
                        HStack(spacing: 6) {
                            Text("Try \(i + 1)").font(.caption.bold())
                            if i == result.chosenIndex {
                                Text("SHOWN")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            if attempt.toolCalls > 0 {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if attempt.usedFallback {
                                Image(systemName: "icloud.slash")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text(String(format: "%.1fs", attempt.seconds))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: attempt.containsWord ? "checkmark" : "xmark")
                                .foregroundStyle(attempt.containsWord ? .green : .red)
                        }
                        if let sentence = attempt.sentence {
                            Text(sentence).textSelection(.enabled)
                            if !attempt.unknownKanji.isEmpty {
                                Text("Unknown kanji: \(String(attempt.unknownKanji))")
                                    .font(.caption)
                                    .foregroundStyle(Color("WKGold"))
                            }
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
