import Testing
import Foundation
@testable import Ownwise

@MainActor
struct CoverageStatusTests {

    @MainActor
    private func coverage(kind: CoverageKind = .manufacturer, end: Date, now: Date, interval: Int? = nil) -> Coverage {
        let c = Coverage(kind: kind, start: now.addingTimeInterval(-86400 * 30), end: end)
        c.serviceIntervalMonths = interval
        c.lastServiceDate = now.addingTimeInterval(-86400 * 30)
        return c
    }

    @Test("Expired when end date is in the past")
    func expired() {
        let now = Date()
        let c = coverage(end: now.addingTimeInterval(-86400), now: now)
        #expect(coverageStatus(of: c, now: now) == .expired)
    }

    @Test("Expiring soon within soonDays")
    func expiringSoon() {
        let now = Date()
        let c = coverage(end: now.addingTimeInterval(86400 * 10), now: now)
        if case .expiringSoon(let d) = coverageStatus(of: c, now: now) {
            #expect(d <= 10)
        } else {
            Issue.record("expected expiringSoon")
        }
    }

    @Test("Active well beyond soonDays")
    func active() {
        let now = Date()
        let c = coverage(end: now.addingTimeInterval(86400 * 90), now: now)
        #expect(coverageStatus(of: c, now: now) == .active)
    }

    @Test("Service due when next service date passed")
    func serviceDue() {
        let now = Date()
        let c = coverage(kind: .servicePlan, end: .distantFuture, now: now, interval: 3)
        c.lastServiceDate = now.addingTimeInterval(-86400 * 100)
        #expect(coverageStatus(of: c, now: now) == .serviceDue)
    }

    @Test("Leap year boundary")
    func leapYear() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2028, month: 2, day: 1))!
        let c = coverage(end: cal.date(from: DateComponents(year: 2028, month: 3, day: 1))!, now: now)
        if case .expiringSoon(let d) = coverageStatus(of: c, now: now, soonDays: 60, calendar: cal) {
            #expect(d == 29) // Feb 2028 has 29 days
        } else {
            Issue.record("expected expiringSoon")
        }
    }

    @Test("DST change does not crash and counts calendar days")
    func dst() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        let c = coverage(end: end, now: now)
        if case .expiringSoon(let d) = coverageStatus(of: c, now: now, soonDays: 30, calendar: cal) {
            #expect(d == 2)
        } else {
            Issue.record("expected expiringSoon")
        }
    }
}
