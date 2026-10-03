import Testing
import Foundation
@testable import Ownwise

@MainActor
struct ReceiptParserTests {

    nonisolated static let fixtures: [(name: String, merchant: String?, total: Int?, currency: String?, warranty: Int?, ret: Int?, text: String)] = [
        ("US Best Buy", "Best Buy", 129950, "USD", 12, 30,
         "Best Buy\nOrder #BBY01-2345678\nDate: 09/15/2026\nGrand Total: $1,299.50\n1 Year Limited Warranty\n30-day return policy"),
        ("US Target", "Target", 4599, "USD", nil, 90,
         "TARGET\nStore #1234\nDate 09/10/2026\nTotal: $45.99\n90 day return"),
        ("UK Currys", "Currys", 89900, "GBP", 12, 14,
         "Currys\nReceipt No: UK-99887\nDate: 10/03/2026\nTotal: £899.00\n12 Month Warranty\n14 day returns"),
        ("EU MediaMarkt dot decimals", "MediaMarkt", 129950, "EUR", 24, 14,
         "MediaMarkt\nDatum: 15.09.2026\nGesamt: 1.299,50 €\n2 Jahre Garantie"),
        ("EU Fnac French", "Fnac", 100000, "EUR", 24, nil,
         "Fnac\nDate: 15/09/2026\nTotal TTC: 1.000,00 €\nGarantie 2 ans"),
        ("JP Bic Camera yen", "Bic Camera", 129950, "JPY", 12, nil,
         "Bic Camera\n日付: 2026/09/15\n合計: ¥129,950\n電子製品保証 1年"),
        ("IN Croma INR", "Croma", 12995000, "INR", 12, 7,
         "CROMA\nInvoice No: IN-12345\nDate: 15/09/2026\nTotal: ₹1,29,950.00\nWarranty: 1 year\n7 day return"),
        ("US comma decimal EU style", "Amazon", 1999, "USD", nil, 30,
         "Amazon\nOrder #: 123-456\nDate: 09/15/2026\nOrder Total: $19.99\n30 day return"),
        ("Decimal dot EU", "Fnac", 4990, "EUR", nil, 30,
         "Fnac\nTotal: 49,90 €\nDate: 03/10/2026"),
        ("Amount Due keyword", "Walmart", 2599, "USD", nil, nil,
         "Walmart\nAmount Due: $25.99\nDate 10/01/2026"),
    ]

    @Test("Parser extracts merchant", arguments: Self.fixtures.filter { $0.merchant != nil }.map(\.text))
    func merchantFound(text: String) {
        let p = ReceiptParser().parse(text)
        #expect(p.merchant != nil)
    }

    @Test("Parser extracts warranty months", arguments: Self.fixtures.filter { $0.warranty != nil }.map(\.text))
    func warrantyFound(text: String) {
        let p = ReceiptParser().parse(text)
        #expect(p.warrantyMonths != nil)
    }

    @Test("Parser extracts total and currency")
    func totals() {
        let p = ReceiptParser()
        let us = p.parse(Self.fixtures[0].text)
        #expect(us.totalMinor == 129950)
        let eu = p.parse(Self.fixtures[3].text)
        #expect(eu.totalMinor == 129950)
        #expect(eu.currencyCode == "EUR")
        let jp = p.parse(Self.fixtures[5].text)
        #expect(jp.totalMinor == 129950) // JPY: 0 minor units
    }

    @Test("Return days")
    func returns() {
        let p = ReceiptParser().parse(Self.fixtures[0].text)
        #expect(p.returnDays == 30)
    }

    @Test("Warranty 1 year = 12 months; Garantie 2 ans = 24")
    func warrantyUnits() {
        let p = ReceiptParser()
        #expect(p.parse(Self.fixtures[0].text).warrantyMonths == 12)
        #expect(p.parse(Self.fixtures[3].text).warrantyMonths == 24)
        #expect(p.parse(Self.fixtures[5].text).warrantyMonths == 12)
    }
}
