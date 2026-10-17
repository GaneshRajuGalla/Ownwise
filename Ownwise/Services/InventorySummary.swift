import Foundation

/// What the library is worth, for an insurance list (E4), and in which currencies (E10).
///
/// **Money is never summed across currencies.** Adding 200 EUR to 300 USD and calling the answer 500
/// would be a wrong number in a document someone hands to an insurer, so every total here is kept per
/// currency. The same reason nothing is sorted by price: minor units of different currencies are not
/// comparable amounts.
@MainActor
enum InventorySummary {

    /// One item that has a price.
    struct Line: Sendable, Equatable {
        var id: UUID
        var name: String
        var category: ItemCategory
        var purchaseDate: Date
        var priceMinor: Int
        var currencyCode: String
    }

    struct Summary: Sendable, Equatable {
        var generatedAt: Date
        var itemCount: Int
        var pricedItemCount: Int
        /// Currency code → minor units. One entry per currency that appears.
        var totalsByCurrency: [String: Int]
        /// Category → currency code → minor units.
        var totalsByCategory: [ItemCategory: [String: Int]]
        /// The priced items, by name.
        var lines: [Line]

        static let empty = Summary(generatedAt: .distantPast, itemCount: 0, pricedItemCount: 0,
                                   totalsByCurrency: [:], totalsByCategory: [:], lines: [])
    }

    static func summarize(_ items: [Item], now: Date = .now) -> Summary {
        var totalsByCurrency: [String: Int] = [:]
        var totalsByCategory: [ItemCategory: [String: Int]] = [:]
        var lines: [Line] = []

        for item in items {
            // A price of zero is a real answer ("this was free"), so only a missing price is skipped.
            guard let price = item.priceMinor else { continue }
            let currency = item.currencyCode.isEmpty
                ? (Locale.current.currency?.identifier ?? "USD")
                : item.currencyCode

            totalsByCurrency[currency, default: 0] += price
            totalsByCategory[item.category, default: [:]][currency, default: 0] += price
            lines.append(Line(id: item.id, name: item.name, category: item.category,
                              purchaseDate: item.purchaseDate, priceMinor: price,
                              currencyCode: currency))
        }

        return Summary(generatedAt: now,
                       itemCount: items.count,
                       pricedItemCount: lines.count,
                       totalsByCurrency: totalsByCurrency,
                       totalsByCategory: totalsByCategory,
                       lines: lines.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }

    /// Currency codes in a stable order, so two runs of the same report look the same.
    nonisolated static func sortedCurrencies(_ totals: [String: Int]) -> [String] {
        totals.keys.sorted()
    }

    /// Splits the lines into pages. Always at least one (possibly empty) page, so a report is never
    /// zero pages long.
    nonisolated static func chunked(_ lines: [Line], perPage: Int) -> [[Line]] {
        guard perPage > 0, !lines.isEmpty else { return [lines] }
        return stride(from: 0, to: lines.count, by: perPage).map {
            Array(lines[$0..<min($0 + perPage, lines.count)])
        }
    }

    /// "3 items", never "1 items" (the habit G2 fixed elsewhere).
    static func itemsPhrase(_ count: Int) -> String {
        switch count {
        case 1: String(localized: "1 item", comment: "Inventory report count")
        default: String(localized: "\(count) items", comment: "Inventory report count")
        }
    }
}
