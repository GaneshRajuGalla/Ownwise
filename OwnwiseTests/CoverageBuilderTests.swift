import Testing
import Foundation
@testable import Ownwise

/// The single place coverage is built (H4). These rules used to be asserted through
/// `CoverageEditor` while two other screens repeated the same arithmetic.
@MainActor
struct CoverageBuilderTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }

    @Test("Coverage counts from its start (purchase date), not from today")
    func endFromStart() {
        let purchase = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        #expect(CoverageBuilder.endDate(kind: .manufacturer, start: purchase, length: 12, calendar: cal)
                == cal.date(from: DateComponents(year: 2027, month: 1, day: 15)))
        #expect(CoverageBuilder.endDate(kind: .returnWindow, start: purchase, length: 30, calendar: cal)
                == cal.date(from: DateComponents(year: 2026, month: 2, day: 14)))
        #expect(CoverageBuilder.endDate(kind: .servicePlan, start: purchase, length: 6, calendar: cal)
                == cal.date(from: DateComponents(year: 2026, month: 7, day: 15)))
    }

    @Test("Sensible defaults per kind")
    func defaults() {
        #expect(CoverageBuilder.defaultLength(.returnWindow) == 30)
        #expect(CoverageBuilder.defaultLength(.manufacturer) == 12)
        #expect(CoverageBuilder.defaultLength(.servicePlan) == 6)
    }

    @Test("A return window is stored as a dated coverage in days")
    func makeReturnWindow() {
        let purchase = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let coverage = CoverageBuilder.make(kind: .returnWindow, start: purchase, length: 30, calendar: cal)
        #expect(coverage.kind == .returnWindow)
        #expect(coverage.startDate == purchase)
        #expect(coverage.endDate == cal.date(from: DateComponents(year: 2026, month: 2, day: 14)))
        #expect(coverage.serviceIntervalMonths == nil)
    }

    @Test("A warranty is stored in months")
    func makeWarranty() {
        let purchase = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let coverage = CoverageBuilder.make(kind: .manufacturer, start: purchase, length: 24, calendar: cal)
        #expect(coverage.endDate == cal.date(from: DateComponents(year: 2028, month: 1, day: 15)))
    }

    @Test("A service plan is stored open-ended, carrying its interval and last service date")
    func makeServicePlan() {
        let lastService = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let coverage = CoverageBuilder.make(kind: .servicePlan, start: lastService, length: 6, calendar: cal)
        // Recurring plans never "end", or the reminder would stop after the first interval.
        #expect(coverage.endDate == Date.distantFuture)
        #expect(coverage.serviceIntervalMonths == 6)
        #expect(coverage.lastServiceDate == lastService)
    }
}
