import Testing
import Foundation
@testable import Ownwise

/// The "expiring soon" horizon (E7).
///
/// The stored value is tested through the pure validator rather than by writing to `UserDefaults`:
/// the tests run in parallel, and a test that temporarily changed the horizon would change what every
/// other test sees.
@MainActor
struct LibraryPreferencesTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        return cal
    }

    @Test("Anything that is not one of the offered horizons reads as 30 days")
    func validation() {
        #expect(LibraryPreferences.soonDays(stored: 0) == LibraryPreferences.defaultSoonDays)
        #expect(LibraryPreferences.soonDays(stored: 1) == 30)
        #expect(LibraryPreferences.soonDays(stored: 45) == 30)
        #expect(LibraryPreferences.soonDays(stored: 7) == 7)
        #expect(LibraryPreferences.soonDays(stored: 90) == 90)
        #expect(LibraryPreferences.soonDayOptions.contains(LibraryPreferences.defaultSoonDays),
                "the default has to be one of the choices, or the picker shows nothing selected")
    }

    @Test("The horizon changes what counts as expiring soon")
    func horizonApplies() {
        let cal = calendar
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let coverage = Coverage(kind: .manufacturer, start: now,
                                end: cal.date(byAdding: .day, value: 20, to: now)!)

        #expect(coverageStatus(of: coverage, now: now, soonDays: 7, calendar: cal) == .active)
        if case .expiringSoon(let days) = coverageStatus(of: coverage, now: now, soonDays: 30, calendar: cal) {
            #expect(days == 20)
        } else {
            Issue.record("20 days out is expiring soon at a 30-day horizon")
        }
    }

    @Test("The horizon reaches the item's overall badge too, not just the coverage's own status")
    func overallStatusUsesTheHorizon() {
        let cal = calendar
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let coverage = Coverage(kind: .manufacturer, start: now,
                                end: cal.date(byAdding: .day, value: 20, to: now)!)

        #expect(overallStatus(of: [coverage], now: now, soonDays: 7, calendar: cal) == .active)
        if case .expiringSoon = overallStatus(of: [coverage], now: now, soonDays: 30, calendar: cal) {} else {
            Issue.record("the item's badge should follow the same horizon")
        }
    }

    @Test("Horizons read as weeks and months, never \"1 days\"")
    func labels() {
        #expect(LibraryPreferences.label(for: 7) == "1 week")
        #expect(LibraryPreferences.label(for: 14) == "2 weeks")
        #expect(LibraryPreferences.label(for: 30) == "1 month")
        #expect(LibraryPreferences.label(for: 90) == "3 months")
        #expect(LibraryPreferences.label(for: 21) == "21 days")
    }
}
