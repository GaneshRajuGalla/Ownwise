import WidgetKit
import SwiftUI

/// The "what's ending" widget, Home Screen and Lock Screen (E2).
///
/// **This file is intentionally not part of any target.** A widget needs its own extension target,
/// its own bundle id, provisioning and an App Group, so it is created in Xcode; the app side — the
/// snapshot it reads — is meanwhile built and tested. `docs/widgets.md` has the steps.
///
/// It reads a file the app writes (`SharedSnapshot`) rather than the SwiftData store, because the app
/// must stay the only writer and a widget's timeline runs off the main actor. When the target is
/// created, add `Ownwise/Services/Import/SharedSnapshot.swift` to it — that file is pure Foundation so
/// it drops in without dragging SwiftData or the app's model into the widget.
struct ExpiringEntry: TimelineEntry {
    let date: Date
    let entries: [SharedSnapshot.Entry]
}

struct ExpiringProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpiringEntry {
        ExpiringEntry(date: .now, entries: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpiringEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpiringEntry>) -> Void) {
        // The app rewrites the snapshot whenever the library changes, so this is only a safety net for
        // a day the app was never opened — the dates themselves are what go stale.
        let next = Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [current()], policy: .after(next)))
    }

    private func current() -> ExpiringEntry {
        ExpiringEntry(date: .now, entries: SharedSnapshot.default.read()?.entries ?? [])
    }

    private static var sample: [SharedSnapshot.Entry] {
        [SharedSnapshot.Entry(id: UUID(), itemID: UUID(), name: "Kettle",
                              kind: "Manufacturer warranty",
                              endDate: Date().addingTimeInterval(6 * 86_400))]
    }
}

struct ExpiringWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ExpiringEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ending soon")
                .font(.caption).bold()
                .foregroundStyle(.secondary)

            if entry.entries.isEmpty {
                Text("Nothing is running out.")
                    .font(.caption)
            } else {
                ForEach(entry.entries.prefix(family == .systemSmall ? 2 : 4)) { item in
                    HStack(spacing: 6) {
                        Text(item.name).font(.caption).bold().lineLimit(1)
                        Spacer(minLength: 4)
                        Text(daysLeft(item.endDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func daysLeft(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return String(localized: "past", comment: "Widget: this date has passed")
        case 0: return String(localized: "today", comment: "Widget: ends today")
        case 1: return String(localized: "1 day", comment: "Widget: ends in one day")
        default: return String(localized: "\(days) days", comment: "Widget: ends in N days")
        }
    }
}

struct ExpiringWidget: Widget {
    let kind = "ExpiringWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpiringProvider()) { entry in
            ExpiringWidgetView(entry: entry)
        }
        .configurationDisplayName("Ending soon")
        .description("What is running out, and when.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryInline])
    }
}

@main
struct OwnwiseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExpiringWidget()
    }
}
