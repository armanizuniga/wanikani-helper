// Lock Screen accessory widget that rotates through vocabulary the user has learned.
// Reads the word pool the app writes into the shared App Group container (WidgetShared),
// and steps through it on a timeline so the word changes over the course of the day.
import WidgetKit
import SwiftUI

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord?
}

struct WordProvider: TimelineProvider {
    private static let sample = WidgetWord(characters: "言葉", reading: "ことば", meaning: "word", level: 1)

    nonisolated func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: Self.sample)
    }

    nonisolated func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        let word = WidgetShared.load().first ?? Self.sample
        completion(WordEntry(date: Date(), word: word))
    }

    nonisolated func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let words = WidgetShared.load().shuffled()
        let now = Date()
        let calendar = Calendar.current

        guard !words.isEmpty else {
            let timeline = Timeline(entries: [WordEntry(date: now, word: nil)], policy: .atEnd)
            completion(timeline)
            return
        }

        // One word every 30 minutes for the next ~24h, cycling through the shuffled pool.
        // iOS decides exactly when to refresh, but this gives it plenty of entries to rotate.
        var entries: [WordEntry] = []
        for step in 0..<48 {
            let date = calendar.date(byAdding: .minute, value: step * 30, to: now) ?? now
            entries.append(WordEntry(date: date, word: words[step % words.count]))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WordEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    @ViewBuilder private var inline: some View {
        if let word = entry.word {
            if word.readingIsRedundant {
                Text("\(word.characters) · \(word.meaning)")
            } else {
                Text("\(word.characters)（\(word.reading)）\(word.meaning)")
            }
        } else {
            Text("Open WaniKani Helper")
        }
    }

    @ViewBuilder private var rectangular: some View {
        if let word = entry.word {
            VStack(alignment: .leading, spacing: 1) {
                Text(word.characters)
                    .font(.system(.title3, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !word.readingIsRedundant {
                    Text(word.reading)
                        .font(.footnote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .widgetAccentable()
                }
                Text(word.meaning)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("WaniKani")
                    .font(.headline)
                Text("Open the app to load words")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LockScreenWordWidget: Widget {
    let kind = "LockScreenWordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            WordEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Vocab Word")
        .description("A WaniKani vocabulary word you've learned, rotating through the day.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
