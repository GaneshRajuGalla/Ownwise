import Foundation

/// One place that turns "a 30-day return window" or a "24-month warranty" into a `Coverage`.
///
/// This arithmetic used to be repeated in `EditItemView`, `ReviewModel`, `CoverageEditor` and the
/// sample data — the same way the two price parsers drifted apart (H4). Every screen that creates
/// coverage goes through here now, and the rules are unit-tested once.
enum CoverageBuilder {

    /// How long a new coverage of its kind runs by default, in that kind's own unit
    /// (days for a return window, months for everything else).
    nonisolated static func defaultLength(_ kind: CoverageKind) -> Int {
        switch kind {
        case .returnWindow: 30
        case .servicePlan: 6
        default: 12
        }
    }

    /// The unit a length is counted in.
    nonisolated static func unit(for kind: CoverageKind) -> Calendar.Component {
        kind == .returnWindow ? .day : .month
    }

    /// End of the coverage. For a service plan this is the *next* service date
    /// (start + interval); `make` stores a recurring plan differently — see below.
    nonisolated static func endDate(kind: CoverageKind, start: Date, length: Int,
                                    calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: unit(for: kind), value: length, to: start) ?? start
    }

    /// The coverage as the app stores it. A return window or policy ends on a date; a service plan
    /// is open-ended (`distantFuture`) and carries the interval it repeats on, so reminders keep
    /// recurring from the last service date.
    nonisolated static func make(kind: CoverageKind, start: Date, length: Int,
                                 calendar: Calendar = .current) -> Coverage {
        let end = kind == .servicePlan
            ? Date.distantFuture
            : endDate(kind: kind, start: start, length: length, calendar: calendar)
        let coverage = Coverage(kind: kind, start: start, end: end)
        if kind == .servicePlan {
            coverage.serviceIntervalMonths = length
            coverage.lastServiceDate = start
        }
        return coverage
    }
}
