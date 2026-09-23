// Intents that act on a single kanji or vocabulary item. Look Up answers in place (meaning,
// reading, level) without opening the app; Open is what Spotlight runs when an indexed item is
// tapped, and shows the item's detail sheet.
import AppIntents
import SwiftUI

struct LookUpSubjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Look Up Word"
    static let description = IntentDescription("Get the meaning, reading and level of a WaniKani kanji or vocabulary word.")

    @Parameter(title: "Word", requestValueDialog: "Which word?")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Look up \(\.$subject)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let s = subject
        var text = "\(s.characters)"
        if let reading = s.reading, reading != s.characters { text += ", read \(reading)," }
        text += " means \(s.meaning). It's a level \(s.level) \(s.typeLabel.lowercased()) item."

        return .result(dialog: IntentDialog(stringLiteral: text), view: SubjectSnippet(subject: s))
    }
}

// "Explain this word" — the fuller answer. Siri speaks one short line; the snippet carries the
// detail (composition, mnemonic, an example sentence). The sentence comes from the saved/bundled
// pools rather than the AI generators: Siri times out long before on-device generation finishes.
struct ExplainSubjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Explain Word"
    static let description = IntentDescription("Explain a WaniKani kanji or vocabulary word: meaning, reading, the parts it's built from, its mnemonic and an example sentence.")

    @Parameter(title: "Word", requestValueDialog: "Which word?")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Explain \(\.$subject)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let s = subject
        let cached = SubjectLookup.subject(id: s.id)
        let parts = cached.map { SubjectLookup.components(of: $0) } ?? []
        let mnemonic = cached?.meaningMnemonic.map(stripWKTags)
        let example = SubjectLookup.exampleSentence(for: s.id)

        var text = "\(s.characters)"
        if let reading = s.reading, reading != s.characters { text += ", read \(reading)," }
        text += " means \(s.meaning)."
        if !parts.isEmpty {
            text += " It's made of " + parts.map { "\($0.characters) (\($0.meaning))" }.joined(separator: " and ") + "."
        }

        return .result(
            dialog: IntentDialog(stringLiteral: text),
            view: ExplainSnippet(subject: s, parts: parts, mnemonic: mnemonic, example: example)
        )
    }
}

// "Say this word" — reads the reading aloud with the same voice as the easy-mode speaker button.
struct SaySubjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Say Word"
    static let description = IntentDescription("Read a WaniKani word's Japanese reading aloud.")

    @Parameter(title: "Word", requestValueDialog: "Which word?")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Say \(\.$subject)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        JapaneseSpeaker.shared.speak(subject.reading ?? subject.characters)
        return .result()
    }
}

struct OpenSubjectIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Word"
    static let description = IntentDescription("Show a WaniKani kanji or vocabulary word in the app.")

    @Parameter(title: "Word")
    var target: SubjectEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .subject(target.id)
        return .result()
    }
}

private struct ExplainSnippet: View {
    let subject: SubjectEntity
    let parts: [SubjectPart]
    let mnemonic: String?
    let example: SubjectLookup.Example?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubjectSnippet(subject: subject)
                .padding(-16)   // SubjectSnippet pads itself; this view pads the whole stack

            if !parts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(parts, id: \.characters) { part in
                        VStack(spacing: 2) {
                            Text(part.characters).font(.system(size: 20))
                            Text(part.meaning).font(.caption2.bold()).lineLimit(1)
                        }
                        .foregroundStyle(subjectTypeColor(part.type))
                        .frame(minWidth: 52)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .background(subjectTypeColor(part.type).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if let mnemonic, !mnemonic.isEmpty {
                Text(mnemonic)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            if let example {
                VStack(alignment: .leading, spacing: 2) {
                    Text(example.japanese).font(.body)
                    if let english = example.english {
                        Text(english).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

private struct SubjectSnippet: View {
    let subject: SubjectEntity

    private var color: Color {
        subject.typeLabel == "Kanji" ? subjectTypeColor(.kanji) : subjectTypeColor(.vocabulary)
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(subject.characters)
                .font(.system(size: 44))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(minWidth: 80)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.meanings.prefix(3).joined(separator: ", "))
                    .font(.headline)
                if !subject.readings.isEmpty {
                    Text(subject.readings.prefix(3).joined(separator: "、"))
                        .font(.title3)
                }
                Text("Level \(subject.level) · \(subject.typeLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}
