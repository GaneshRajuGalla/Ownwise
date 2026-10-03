import Foundation

/// Deterministic, locale-aware parser. Baseline truth; AI only fills gaps.
struct ReceiptParser: Sendable {

    struct Parsed: Sendable {
        var merchant: String?
        var productName: String?
        var purchaseDate: Date?
        var totalMinor: Int?
        var currencyCode: String?
        var orderNumber: String?
        var taxID: String?
        var warrantyMonths: Int?
        var returnDays: Int?
        var serialNumber: String?
    }

    private nonisolated static let totalKeywords = ["grand total", "total", "amount due", "balance", "gesamt",
                                        "total ttc", "importe", "合計", "jumlah", "montant total",
                                        "total a pagar", "importe total", "gesamtbetrag", "总计", "total due"]
    private nonisolated static let warrantyKeywords = ["warranty", "guarantee", "garantie", "garantía", "garantia", "保証", "garantia", "warranties"]
    private nonisolated static let returnKeywords = ["return", "refund", "exchange", "returns"]

    nonisolated func parse(_ text: String) -> Parsed {
        var p = Parsed()
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        p.merchant = merchantName(lines: lines)
        p.productName = productName(in: lines, merchant: p.merchant)
        p.purchaseDate = parseDate(text: text)
        p.totalMinor = parseTotal(lines: lines)
        p.currencyCode = parseCurrency(text: text)
        p.orderNumber = first(regex: #"(?i)(?:order|invoice|receipt|transaction|bill)\s*(?:no|#|number|id)?[.:\s#-]*([A-Z0-9][A-Z0-9\-/]{3,20})"#, in: text)
        p.taxID = parseTaxID(text: text)
        p.warrantyMonths = parseWarranty(text: text)
        p.returnDays = parseReturnWindow(text: text)
        p.serialNumber = first(regex: #"(?i)(?:s/?n|serial|imei)[.:\s]*([A-Z0-9]{8,20})"#, in: text)
        return p
    }

    // MARK: - Date
    nonisolated func parseDate(text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let ns = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard let first = matches.compactMap(\.date).first else { return nil }
        // Prefer dates near a date-ish label.
        let labels = ["date", "order date", "invoice date", "datum", "fecha", "日付", "date de"]
        for m in matches {
            guard let d = m.date else { continue }
            let around = ns.substring(with: NSRange(location: max(0, m.range.location - 20), length: min(60, ns.length - max(0, m.range.location - 20)))).lowercased()
            if labels.contains(where: { around.contains($0) }) { return d }
        }
        return first
    }

    // MARK: - Total
    nonisolated func parseTotal(lines: [String]) -> Int? {
        var best: Double?
        for line in lines {
            let lower = line.lowercased()
            guard Self.totalKeywords.contains(where: { lower.contains($0) }) else { continue }
            // Largest number on the line.
            let numbers = allNumbers(in: line)
            if let max = numbers.max() { if best == nil || max > best! { best = max } }
        }
        guard let total = best else { return nil }
        return minorUnits(total, currencyCode: parseCurrencyFromAmountText(lines.joined(separator: "\n")) ?? "")
    }

    nonisolated func allNumbers(in s: String) -> [Double] {
        let pattern = #"[0-9]{1,3}(?:[.,\s]?[0-9]{3})*(?:[.,][0-9]{1,2})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = s as NSString
        return regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            parseAmount(ns.substring(with: $0.range))
        }
    }

    /// Handles "1.299,50" (EU) and "1,299.50" (US) and "1299.50".
    nonisolated func parseAmount(_ raw: String) -> Double? {
        let s = raw.replacingOccurrences(of: " ", with: "")
        if let lastDot = s.lastIndex(of: "."), let lastComma = s.lastIndex(of: ",") {
            if lastComma > lastDot {
                return Double(s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
            }
            return Double(s.replacingOccurrences(of: ",", with: ""))
        }
        if s.contains(",") {
            if let tail = s.split(separator: ",").last, tail.count == 2 {
                return Double(s.replacingOccurrences(of: ",", with: "."))
            }
            return Double(s.replacingOccurrences(of: ",", with: ""))
        }
        return Double(s)
    }

    nonisolated func minorUnits(_ amount: Double, currencyCode: String) -> Int {
        let zeroDecimal = ["JPY", "KRW", "VND", "ISK"]
        let factor = zeroDecimal.contains(currencyCode.uppercased()) ? 1.0 : 100.0
        return Int((amount * factor).rounded())
    }

    // MARK: - Currency
    nonisolated func parseCurrency(text: String) -> String? {
        let table: [(String, String)] = [
            ("A$", "AUD"), ("C$", "CAD"), ("CHF", "CHF"), ("AED", "AED"), ("IDR", "IDR"),
            ("INR", "INR"), ("₹", "INR"), ("$", "USD"), ("€", "EUR"), ("£", "GBP"),
            ("¥", "JPY"), ("￥", "JPY"), ("EUR", "EUR"), ("USD", "USD"), ("GBP", "GBP"), ("JPY", "JPY")
        ]
        for (symbol, code) in table where text.contains(symbol) { return code }
        return Locale.current.currency?.identifier
    }

    nonisolated func parseCurrencyFromAmountText(_ text: String) -> String? { parseCurrency(text: text) }

    /// Merchant: prefer an explicit "Merchant:/Seller:" line; else the first
    /// short line that looks like a brand/store name and isn't a title line.
    nonisolated func merchantName(lines: [String]) -> String? {
        if let m = labeledValue(label: ["merchant", "seller", "store", "retailer"], in: lines) { return m }
        return lines.first(where: { line in
            line.count >= 3 &&
            line.rangeOfCharacter(from: .decimalDigits) == nil &&
            !Self.totalKeywords.contains(where: { line.lowercased().contains($0) }) &&
            line.lowercased().contains("warranty") == false &&
            line.lowercased().contains("guarantee") == false &&
            line.lowercased().contains("receipt") == false &&
            line.lowercased().hasPrefix("product") == false &&
            line.lowercased().hasPrefix("brand") == false
        })
    }

    /// Product name: prefer explicit "Product:/Item:/Model:" line, else first
    /// product-like line that isn't a merchant/merchant-title/date/total line.
    nonisolated func productName(in lines: [String], merchant: String?) -> String? {
        if let p = labeledValue(label: ["product", "item", "model", "description", "article"], in: lines) { return p }
        return lines.first(where: { line in
            line.count > 4 &&
            line.rangeOfCharacter(from: .letters) != nil &&
            !Self.totalKeywords.contains(where: { line.lowercased().contains($0) }) &&
            line.lowercased().contains("warranty") == false &&
            line.lowercased().contains("guarantee") == false &&
            !(merchant != nil && line.contains(merchant!)) &&
            !line.lowercased().hasPrefix("s/n") &&
            !line.lowercased().hasPrefix("serial") &&
            !line.lowercased().hasPrefix("order") &&
            !line.lowercased().hasPrefix("date") &&
            !line.lowercased().hasPrefix("support") &&
            !line.lowercased().hasPrefix("brand")
        })
    }

    /// Extracts the value after "Label:" or "Label -" case-insensitively.
    nonisolated func labeledValue(label labels: [String], in lines: [String]) -> String? {
        for line in lines {
            let lower = line.lowercased()
            for l in labels where lower.hasPrefix(l + ":") || lower.hasPrefix(l + " :") || lower.hasPrefix(l + " -") || lower.hasPrefix(l + " –") {
                let value = line.dropFirst(line.prefix(while: { $0 != ":" && $0 != "-" && $0 != "–" }).count + 1).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    // MARK: - Tax ID
    nonisolated func parseTaxID(text: String) -> String? {
        if let v = first(regex: #"\b([A-Z]{2}[0-9A-Z]{8,12})\b"#, in: text), text.lowercased().contains("vat") { return v }
        if let g = first(regex: #"\b\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]\b"#, in: text) { return g }
        return nil
    }

    // MARK: - Warranty / return
    nonisolated func parseWarranty(text: String) -> Int? {
        for line in text.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            guard Self.warrantyKeywords.contains(where: { lower.contains($0) }) else { continue }
            guard let regex = try? NSRegularExpression(pattern: #"(\d{1,3})\s*(years?|yrs?|months?|mos?|jahre?|años?|ans?|年)"#) else { continue }
            let ns = lower as NSString
            guard let m = regex.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)) else { continue }
            guard let value = Int(ns.substring(with: m.range(at: 1))) else { continue }
            let unit = ns.substring(with: m.range(at: 2))
            let isYear = unit.hasPrefix("y") || unit.hasPrefix("j") || unit.hasPrefix("a") || unit == "年"
            return isYear ? value * 12 : value
        }
        return nil
    }

    nonisolated func parseReturnWindow(text: String) -> Int? {
        for line in text.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            guard Self.returnKeywords.contains(where: { lower.contains($0) }) else { continue }
            if let d = first(regex: #"(\d{1,3})[\s-]*day"#, in: lower), let v = Int(d) { return v }
        }
        return nil
    }

    // MARK: - Helpers
    nonisolated func first(regex pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let idx = m.numberOfRanges >= 2 ? 1 : 0
        return ns.substring(with: m.range(at: idx))
    }
}
