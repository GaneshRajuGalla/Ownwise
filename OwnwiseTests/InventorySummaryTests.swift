import Testing
import Foundation
@testable import Ownwise

/// The maths behind the inventory report (E4) and its per-currency rule (E10).
@MainActor
struct InventorySummaryTests {

    private func item(_ name: String, price: Int?, currency: String = "USD",
                      category: ItemCategory = .other) -> Item {
        let item = Item(name: name)
        item.category = category
        item.currencyCode = currency
        item.priceMinor = price
        return item
    }

    private func line(_ index: Int) -> InventorySummary.Line {
        InventorySummary.Line(id: UUID(), name: "Item \(index)", category: .other,
                              purchaseDate: .now, priceMinor: 100, currencyCode: "USD")
    }

    @Test("Totals are kept per currency and are never added together")
    func perCurrency() {
        let summary = InventorySummary.summarize([
            item("TV", price: 129_950),
            item("Kettle", price: 4_999, currency: "EUR"),
            item("Chair", price: 20_000),
        ])

        #expect(summary.itemCount == 3)
        #expect(summary.pricedItemCount == 3)
        #expect(summary.totalsByCurrency == ["USD": 149_950, "EUR": 4_999])
    }

    @Test("A missing price is not money; a price of zero is")
    func unpriced() {
        let summary = InventorySummary.summarize([item("TV", price: nil), item("Kettle", price: 0)])

        #expect(summary.itemCount == 2)
        #expect(summary.pricedItemCount == 1)
        #expect(summary.totalsByCurrency == ["USD": 0])
        #expect(summary.lines.map(\.name) == ["Kettle"])
    }

    @Test("Category subtotals account for exactly the same money as the totals")
    func byCategory() {
        let summary = InventorySummary.summarize([
            item("TV", price: 60_000, category: .electronics),
            item("Phone", price: 40_000, category: .electronics),
            item("Washer", price: 30_000, category: .appliance),
        ])

        #expect(summary.totalsByCategory[.electronics] == ["USD": 100_000])
        #expect(summary.totalsByCategory[.appliance] == ["USD": 30_000])
        #expect(summary.totalsByCategory[.furniture] == nil)

        let byCategory = summary.totalsByCategory.values.flatMap { $0.values }.reduce(0, +)
        let totals = summary.totalsByCurrency.values.reduce(0, +)
        #expect(byCategory == totals)
    }

    @Test("Lines are listed by name")
    func linesSorted() {
        let summary = InventorySummary.summarize([item("Washer", price: 1), item("kettle", price: 1)])

        #expect(summary.lines.map(\.name) == ["kettle", "Washer"])
    }

    @Test("Pagination never drops an item, and never returns zero pages")
    func pagination() {
        #expect(InventorySummary.chunked([], perPage: 20).count == 1, "a report is never zero pages")

        let chunks = InventorySummary.chunked((0..<45).map(line), perPage: 20)

        #expect(chunks.map(\.count) == [20, 20, 5])
        #expect(chunks.flatMap { $0 }.map(\.name).contains("Item 44"))
    }

    @Test("Currencies are listed in a stable order")
    func currencyOrder() {
        #expect(InventorySummary.sortedCurrencies(["USD": 1, "EUR": 2, "GBP": 3]) == ["EUR", "GBP", "USD"])
        #expect(InventorySummary.sortedCurrencies([:]).isEmpty)
    }

    @Test("Counts read as words: 1 item, 2 items")
    func phrasing() {
        #expect(InventorySummary.itemsPhrase(1) == "1 item")
        #expect(InventorySummary.itemsPhrase(2) == "2 items")
        #expect(InventorySummary.itemsPhrase(0) == "0 items")
    }
}
