import Foundation

/// How far ahead "expiring soon" looks (E7).
///
/// This is read straight from `UserDefaults` rather than being handed down the view hierarchy, because
/// the horizon is needed by free functions (`coverageStatus`, `overallStatus`) that have no environment
/// to read it from. One setting, read wherever the question is asked, is the only way the badge on an
/// item, the chips on Home and the widget's snapshot cannot disagree. Screens re-read it whenever they
/// are shown, which is exactly when it can have changed.
///
/// `nonisolated`: a pure lookup, callable from any context.
nonisolated enum LibraryPreferences {

    /// Thirty days unless the user has chosen otherwise.
    static let defaultSoonDays = 30

    /// The horizons offered — a week, a fortnight, a month, a season, a quarter. Enough choice to be
    /// useful for both a return window and a five-year warranty, not so much that it becomes a puzzle.
    static let soonDayOptions = [7, 14, 30, 60, 90]

    static let key = "expiringSoonDays"

    /// What is stored, validated: anything that is not one of the offered horizons (a stale value, a
    /// value from a future version, nothing at all) reads as the default rather than changing the
    /// meaning of every badge in the app.
    nonisolated static func soonDays(stored: Int) -> Int {
        soonDayOptions.contains(stored) ? stored : defaultSoonDays
    }

    static var soonDays: Int {
        get { soonDays(stored: UserDefaults.standard.integer(forKey: key)) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// How a horizon reads in the picker: weeks and months, never "1 days" (G2's rule, applied by hand
    /// because the count is a duration rather than a count of things).
    nonisolated static func label(for days: Int) -> String {
        switch days {
        case 7: String(localized: "1 week", comment: "Expiring-soon horizon")
        case 14: String(localized: "2 weeks", comment: "Expiring-soon horizon")
        case 30: String(localized: "1 month", comment: "Expiring-soon horizon")
        case 60: String(localized: "2 months", comment: "Expiring-soon horizon")
        case 90: String(localized: "3 months", comment: "Expiring-soon horizon")
        default: String(localized: "\(days) days", comment: "Expiring-soon horizon")
        }
    }
}
