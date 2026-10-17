import Foundation

/// Fills in the widget snapshot from the library (E2).
///
/// The rules are the Home screen's "needs attention" rules (`LibraryInsights`, `coverageStatus`), with
/// the dates kept instead of just a count — a widget that says "3 things" is useless, one that says
/// "Kettle — 6 days" is the whole point.
@MainActor
enum SnapshotBuilder {

    /// The next things to lose cover, soonest first.
    ///
    /// Long-expired coverage is deliberately left out: nothing can be done about it, so a widget that
    /// only ever showed it would be permanent noise.
    static func value(from items: [Item], now: Date = .now, calendar: Calendar = .current) -> SharedSnapshot.Value {
        var found: [(entry: SharedSnapshot.Entry, sortDate: Date)] = []

        for item in items {
            for coverage in item.coverages ?? [] {
                let sortDate: Date
                switch coverageStatus(of: coverage, now: now, calendar: calendar) {
                case .expiringSoon:
                    sortDate = coverage.endDate
                case .serviceDue:
                    // For a plan, the date that matters is when the service is due.
                    guard let next = coverage.nextServiceDate else { continue }
                    sortDate = next
                case .active, .expired:
                    continue
                }
                found.append((SharedSnapshot.Entry(id: coverage.id, itemID: item.id,
                                                   name: item.name, kind: coverage.kind.label,
                                                   endDate: sortDate),
                              sortDate))
            }
        }

        let sorted = found.sorted {
            $0.sortDate == $1.sortDate ? $0.entry.name < $1.entry.name : $0.sortDate < $1.sortDate
        }
        return SharedSnapshot.Value(generatedAt: now, entries: sorted.prefix(SharedSnapshot.maxEntries).map(\.entry))
    }

    /// Writes the library's snapshot, unless there is nowhere to write it (no App Group).
    static func refresh(items: [Item], into snapshot: SharedSnapshot = .default, now: Date = .now) {
        guard snapshot.isAvailable else { return }
        snapshot.write(value(from: items, now: now))
    }
}
