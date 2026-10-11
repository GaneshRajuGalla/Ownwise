import Testing
import Foundation
@testable import Ownwise

@MainActor
struct CoverageEditorTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }

    @Test("Coverage counts from its start (purchase date), not from today")
    func endFromStart() {
        let purchase = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        #expect(CoverageEditor.endDate(kind: .manufacturer, start: purchase, length: 12, calendar: cal)
                == cal.date(from: DateComponents(year: 2027, month: 1, day: 15)))
        #expect(CoverageEditor.endDate(kind: .returnWindow, start: purchase, length: 30, calendar: cal)
                == cal.date(from: DateComponents(year: 2026, month: 2, day: 14)))
        #expect(CoverageEditor.endDate(kind: .servicePlan, start: purchase, length: 6, calendar: cal)
                == cal.date(from: DateComponents(year: 2026, month: 7, day: 15)))
    }

    @Test("Sensible defaults per kind")
    func defaults() {
        #expect(CoverageEditor.defaultLength(.returnWindow) == 30)
        #expect(CoverageEditor.defaultLength(.manufacturer) == 12)
        #expect(CoverageEditor.defaultLength(.servicePlan) == 6)
    }
}
