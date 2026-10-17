import Foundation

/// Prices are stored as integer minor units in the item's currency
/// (cents for USD/EUR, whole yen for JPY). This is the single place that converts.
enum Money {
    /// Building a `NumberFormatter` is expensive and a currency's exponent never changes during
    /// a run, so each one is built once and remembered. The lock guards the cache itself; the
    /// formatters are only ever read after they are stored.
    private static let digitsLock = NSLock()
    nonisolated(unsafe) private static var digitsByCurrency: [String: Int] = [:]

    /// Decimal places the currency uses (2 for USD, 0 for JPY, 3 for KWD).
    nonisolated static func fractionDigits(for currencyCode: String) -> Int {
        let code = currencyCode.isEmpty ? (Locale.current.currency?.identifier ?? "USD") : currencyCode
        digitsLock.lock()
        defer { digitsLock.unlock() }
        if let cached = digitsByCurrency[code] { return cached }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits
        digitsByCurrency[code] = digits
        return digits
    }

    nonisolated static func minorUnits(_ amount: Double, currencyCode: String) -> Int {
        Int((amount * pow(10, Double(fractionDigits(for: currencyCode)))).rounded())
    }

    nonisolated static func amount(_ minorUnits: Int, currencyCode: String) -> Double {
        Double(minorUnits) / pow(10, Double(fractionDigits(for: currencyCode)))
    }

    /// Plain number for editing / CSV, e.g. "1299.50" or "129950" (no grouping, "." decimal).
    nonisolated static func plainString(_ minorUnits: Int, currencyCode: String) -> String {
        let digits = fractionDigits(for: currencyCode)
        return String(format: "%.\(digits)f", amount(minorUnits, currencyCode: currencyCode))
    }

    /// Localized display, e.g. "$1,299.50" or "¥129,950".
    nonisolated static func formatted(_ minorUnits: Int, currencyCode: String) -> String {
        let code = currencyCode.isEmpty ? (Locale.current.currency?.identifier ?? "USD") : currencyCode
        return amount(minorUnits, currencyCode: code).formatted(.currency(code: code))
    }
}
