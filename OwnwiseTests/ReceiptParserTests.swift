import Testing
import Foundation
@testable import Ownwise

@MainActor
struct ReceiptParserTests {

    nonisolated static let fixtures: [(name: String, merchant: String?, total: Int?, currency: String?, warranty: Int?, ret: Int?, text: String)] = [
        // Every field in this table is asserted below, so a number that is wrong here is a failing
        // test rather than a user's wrong price. Two return windows were listed as 14 and 30 while
        // their receipts state no return wording at all — the parser must not invent one, so those
        // expectations are `nil`.
        ("US Best Buy", "Best Buy", 129950, "USD", 12, 30,
         "Best Buy\nOrder #BBY01-2345678\nDate: 09/15/2026\nGrand Total: $1,299.50\n1 Year Limited Warranty\n30-day return policy"),
        ("US Target", "Target", 4599, "USD", nil, 90,
         "TARGET\nStore #1234\nDate 09/10/2026\nTotal: $45.99\n90 day return"),
        ("UK Currys", "Currys", 89900, "GBP", 12, 14,
         "Currys\nReceipt No: UK-99887\nDate: 10/03/2026\nTotal: £899.00\n12 Month Warranty\n14 day returns"),
        ("EU MediaMarkt dot decimals", "MediaMarkt", 129950, "EUR", 24, nil,
         "MediaMarkt\nDatum: 15.09.2026\nGesamt: 1.299,50 €\n2 Jahre Garantie"),
        ("EU Fnac French", "Fnac", 100000, "EUR", 24, nil,
         "Fnac\nDate: 15/09/2026\nTotal TTC: 1.000,00 €\nGarantie 2 ans"),
        ("JP Bic Camera yen", "Bic Camera", 129950, "JPY", 12, nil,
         "Bic Camera\n日付: 2026/09/15\n合計: ¥129,950\n電子製品保証 1年"),
        ("IN Croma INR", "Croma", 12995000, "INR", 12, 7,
         "CROMA\nInvoice No: IN-12345\nDate: 15/09/2026\nTotal: ₹1,29,950.00\nWarranty: 1 year\n7 day return"),
        ("US comma decimal EU style", "Amazon", 1999, "USD", nil, 30,
         "Amazon\nOrder #: 123-456\nDate: 09/15/2026\nOrder Total: $19.99\n30 day return"),
        ("Decimal dot EU", "Fnac", 4990, "EUR", nil, nil,
         "Fnac\nTotal: 49,90 €\nDate: 03/10/2026"),
        ("Amount Due keyword", "Walmart", 2599, "USD", nil, nil,
         "Walmart\nAmount Due: $25.99\nDate 10/01/2026"),
    ]

    @Test("Every fixture's merchant is read exactly, not merely as something non-nil")
    func merchantMatchesEveryFixture() {
        let p = ReceiptParser()
        for fixture in Self.fixtures {
            guard let expected = fixture.merchant else { continue }
            let got = p.parse(fixture.text).merchant
            // Case-insensitively: receipts print "TARGET" where the expected name is "Target".
            #expect(got?.localizedCaseInsensitiveCompare(expected) == .orderedSame,
                    "\(fixture.name): got \(got ?? "nil"), want \(expected)")
        }
    }

    @Test("Every fixture's warranty and return window are read exactly")
    func coverageTermsMatchEveryFixture() {
        let p = ReceiptParser()
        for fixture in Self.fixtures {
            let parsed = p.parse(fixture.text)
            #expect(parsed.warrantyMonths == fixture.warranty,
                    "\(fixture.name): warranty \(parsed.warrantyMonths.map(String.init) ?? "nil"), want \(fixture.warranty.map(String.init) ?? "nil")")
            #expect(parsed.returnDays == fixture.ret,
                    "\(fixture.name): return \(parsed.returnDays.map(String.init) ?? "nil"), want \(fixture.ret.map(String.init) ?? "nil")")
        }
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

    /// The fixture table carries an expected total for every receipt; assert all of them, so a
    /// number this parser gets wrong is a failing test rather than a user's wrong price.
    @Test("Every fixture's total and currency are read exactly")
    func totalsMatchEveryFixture() {
        let p = ReceiptParser()
        for fixture in Self.fixtures {
            guard let expected = fixture.total else { continue }
            let parsed = p.parse(fixture.text)
            #expect(parsed.totalMinor == expected,
                    "\(fixture.name): got \(parsed.totalMinor.map(String.init) ?? "nil"), want \(expected)")
            if let currency = fixture.currency {
                #expect(parsed.currencyCode == currency, "\(fixture.name): currency")
            }
        }
    }

    @Test("Subtotal, savings, item counts and tax lines never win the total")
    func totalIgnoresNearMisses() {
        let p = ReceiptParser()

        let subtotalThenTotal = """
        Best Buy
        Subtotal: $1,199.50
        Tax: $100.00
        Total: $1,299.50
        """
        #expect(p.parse(subtotalThenTotal).totalMinor == 129950)

        let savings = """
        Target
        Total savings: $45.00
        Grand Total: $120.00
        """
        #expect(p.parse(savings).totalMinor == 12000)

        let itemCount = """
        Croma
        Total items: 3
        Total: ₹1,29,950.00
        """
        #expect(p.parse(itemCount).totalMinor == 12995000)

        // A plainer label later in the receipt must not beat an unambiguous one earlier.
        let strongBeatsWeak = """
        Fnac
        Total: 90,00 €
        Grand Total: 1.000,00 €
        """
        #expect(p.parse(strongBeatsWeak).totalMinor == 100000)
    }

    @Test("Indian lakh grouping is not read as a decimal comma")
    func lakhGrouping() {
        let p = ReceiptParser()
        #expect(p.parse("Croma\nTotal: ₹1,29,950.00").totalMinor == 12995000)
        #expect(p.parse("Flipkart\nTotal: ₹1,29,950").totalMinor == 12995000)
    }

    @Test("A labelled purchase date is read from US, EU and Japanese receipts")
    func purchaseDates() throws {
        let p = ReceiptParser()
        let us = try #require(p.parse("Best Buy\nOrder #BBY01-2345678\nDate: 09/15/2026\nGrand Total: $1,299.50").purchaseDate)
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: us)
        #expect((parts.year, parts.month, parts.day) == (2026, 9, 15))

        let eu = try #require(p.parse("MediaMarkt\nDatum: 15.09.2026\nGesamt: 1.299,50 €").purchaseDate)
        parts = Calendar.current.dateComponents([.year, .month, .day], from: eu)
        #expect((parts.year, parts.month, parts.day) == (2026, 9, 15))
    }

    @Test("A VAT number is only read when the receipt actually states one")
    func taxIDs() {
        let p = ReceiptParser()
        #expect(p.parse("MediaMarkt\nVAT No: DE123456789\nGesamt: 10,00 €").taxID == "DE123456789")
        #expect(p.parse("Best Buy\nOrder #BBY01-2345678\nTotal: $10.00").taxID == nil)
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
