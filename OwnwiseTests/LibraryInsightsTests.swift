import Testing
import Foundation
@testable import Ownwise

/// The home screen's counting rules, pulled out of the view so they can be tested (H3).
@MainActor
struct LibraryInsightsTests {

    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func date(_ daysFromNow: Int) -> Date {
        cal.date(byAdding: .day, value: daysFromNow, to: now)!
    }

    private func item(_ name: String, _ coverage: Coverage) -> Item {
        let item = Item(name: name)
        item.coverages = [coverage]
        return item
    }

    private var library: [Item] {
        let returnSoon = item("Phone", Coverage(kind: .returnWindow, start: date(-5), end: date(10)))
        let warrantySoon = item("Laptop", Coverage(kind: .manufacturer, start: date(-5), end: date(20)))
        let farAway = item("Sofa", Coverage(kind: .manufacturer, start: date(-5), end: date(200)))
        let expired = item("Old kettle", Coverage(kind: .returnWindow, start: date(-60), end: date(-10)))
        let service = Coverage(kind: .servicePlan, start: date(-370), end: .distantFuture)
        service.serviceIntervalMonths = 6
        service.lastServiceDate = date(-365) // next service was due months ago
        return [returnSoon, warrantySoon, farAway, expired, item("Washer", service)]
    }

    @Test("Each chip counts the coverages behind it")
    func counts() {
        let counts = LibraryInsights.counts(of: library, now: now)
        #expect(counts.expiringReturn == 1)
        #expect(counts.expiringOther == 1)
        #expect(counts.serviceDue == 1)
        #expect(counts.covered == 1)
    }

    @Test("Needs attention means expiring soon or due for service, never long-expired")
    func needsAttention() {
        let names = LibraryInsights.needsAttention(in: library, now: now).map(\.name)
        #expect(names.contains("Phone"))
        #expect(names.contains("Laptop"))
        #expect(names.contains("Washer"))
        #expect(!names.contains("Sofa"), "a coverage with months left is not attention")
        #expect(!names.contains("Old kettle"), "expired coverage is not actionable")
        #expect(names.count == 3)
    }

    @Test("An empty library counts as nothing, not a crash")
    func emptyLibrary() {
        let counts = LibraryInsights.counts(of: [], now: now)
        #expect(counts == LibraryInsights.CoverageCounts())
        #expect(LibraryInsights.needsAttention(in: [], now: now).isEmpty)
    }
}
