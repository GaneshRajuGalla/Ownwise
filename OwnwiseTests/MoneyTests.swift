import Testing
import Foundation
@testable import Ownwise

struct MoneyTests {

    @Test("Minor units follow each currency's decimals", arguments: [
        (1299.50, "USD", 129950), (1299.50, "EUR", 129950),
        (129950.0, "JPY", 129950), (25000.0, "KRW", 25000),
        (1.234, "KWD", 1234), (499.0, "INR", 49900),
    ])
    func minorUnits(amount: Double, code: String, expected: Int) {
        #expect(Money.minorUnits(amount, currencyCode: code) == expected)
    }

    @Test("Round-trip: minor units back to a plain editable amount")
    func plainString() {
        #expect(Money.plainString(129950, currencyCode: "USD") == "1299.50")
        #expect(Money.plainString(129950, currencyCode: "JPY") == "129950")
        #expect(Money.amount(129950, currencyCode: "JPY") == 129950)
    }

    @Test("Yen is never shown with cents")
    func yenDisplay() {
        let text = Money.formatted(129950, currencyCode: "JPY")
        #expect(!text.contains("1,299.50"), "\(text)")
        #expect(text.filter(\.isNumber) == "129950", "\(text)")
    }

    @Test("A currency's decimals are read once and then reused")
    func fractionDigitsAreStable() {
        #expect(Money.fractionDigits(for: "USD") == 2)
        #expect(Money.fractionDigits(for: "EUR") == 2)
        #expect(Money.fractionDigits(for: "JPY") == 0)
        #expect(Money.fractionDigits(for: "KWD") == 3)
        // Second reads come from the cache and must agree with the first.
        #expect(Money.fractionDigits(for: "USD") == 2)
        #expect(Money.fractionDigits(for: "KWD") == 3)
    }
}
