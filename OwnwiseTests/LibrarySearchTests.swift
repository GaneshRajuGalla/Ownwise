import Testing
import Foundation
@testable import Ownwise

/// The search rules, tested directly instead of through a UI test whose every assertion was
/// optional (I1, I4).
@MainActor
struct LibrarySearchTests {

    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func date(_ daysFromNow: Int) -> Date {
        cal.date(byAdding: .day, value: daysFromNow, to: now)!
    }

    private func library() -> [Item] {
        let phone = Item(name: "Pixel 9")
        phone.brand = "Google"
        phone.serialNumber = "SN-PIXEL-9"
        phone.merchant = "Best Buy"
        phone.orderNumber = "BBY-1234"
        phone.coverages = [Coverage(kind: .returnWindow, start: date(-5), end: date(10))]

        let laptop = Item(name: "MacBook Air")
        laptop.modelNumber = "M4-13"
        laptop.coverages = [Coverage(kind: .manufacturer, start: date(-5), end: date(400))]

        let kettle = Item(name: "Kettle")
        kettle.coverages = [Coverage(kind: .manufacturer, start: date(-500), end: date(-30))]

        let washer = Item(name: "Washer")
        let service = Coverage(kind: .servicePlan, start: date(-370), end: .distantFuture)
        service.serviceIntervalMonths = 6
        service.lastServiceDate = date(-365)
        washer.coverages = [service]

        return [phone, laptop, kettle, washer]
    }

    @Test("A blank query is no filter, not an empty result")
    func blankQuery() {
        #expect(LibrarySearch.filter(library(), query: "", now: now).count == 4)
        #expect(LibrarySearch.filter(library(), query: "   ", now: now).count == 4)
    }

    @Test("Searching finds an item by anything the user typed on it", arguments: [
        "Pixel", "Google", "M4-13", "SN-PIXEL-9", "Best Buy", "BBY-1234",
    ])
    func searchableFields(query: String) {
        let found = LibrarySearch.filter(library(), query: query, now: now).map(\.name)
        #expect(found.count == 1, "expected exactly one match for \(query), got \(found)")
    }

    @Test("Search also reads the receipt text stored with an item")
    func searchesReceiptText() {
        let items = library()
        let attachment = Attachment(kind: .receipt, data: Data([0x01]), contentType: "public.jpeg")
        attachment.ocrText = "Thanks for shopping at Micro Center"
        items[1].attachments = [attachment]

        #expect(LibrarySearch.filter(items, query: "Micro Center", now: now).map(\.name) == ["MacBook Air"])
    }

    @Test("Each status filter matches exactly what it promises")
    func statusFilters() {
        let items = library()
        #expect(LibrarySearch.filter(items, query: "", status: .all, now: now).count == 4)
        #expect(LibrarySearch.filter(items, query: "", status: .active, now: now).map(\.name) == ["MacBook Air"])
        #expect(LibrarySearch.filter(items, query: "", status: .expiring, now: now).map(\.name) == ["Pixel 9"])
        #expect(LibrarySearch.filter(items, query: "", status: .expired, now: now).map(\.name) == ["Kettle"])
        #expect(LibrarySearch.filter(items, query: "", status: .serviceDue, now: now).map(\.name) == ["Washer"])
    }

    @Test("Text and status filters must both match")
    func combined() {
        let items = library()
        #expect(LibrarySearch.filter(items, query: "MacBook", status: .active, now: now).map(\.name) == ["MacBook Air"])
        #expect(LibrarySearch.filter(items, query: "MacBook", status: .expired, now: now).isEmpty,
                "a text match does not override the status filter")
    }
}
