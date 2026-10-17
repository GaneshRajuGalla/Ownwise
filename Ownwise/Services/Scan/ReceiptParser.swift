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

    /// Labels that can only mean "the amount paid".
    private nonisolated static let strongTotalKeywords = ["grand total", "total due", "amount due",
                                                 "balance due", "gesamtbetrag", "importe total",
                                                 "montant total", "total ttc", "total a pagar",
                                                 "total a pagar", "总计", "合計"]
    /// Labels that usually mean the amount paid, but appear on other lines too.
    private nonisolated static let totalKeywords = ["total", "amount", "balance", "gesamt", "summe",
                                        "importe", "montant", "jumlah", "合計額"]
    /// Lines that contain a total word without being the amount paid. Word boundaries already
    /// stop "Subtotal" matching "total"; these catch the multi-word cases.
    private nonisolated static let totalNoise = ["subtotal", "sub-total", "sub total", "total savings",
                                     "total saved", "total items", "total qty", "total quantity",
                                     "total units", "total tax", "total vat", "total gst",
                                     "total discount", "total weight", "total shipping",
                                     "total delivery", "total before", "total excl", "total ex.",
                                     "tax total", "items total", "amount tendered", "tendered",
                                     "total savings", "savings total", "you saved", "total points"]
    private nonisolated static let warrantyKeywords = ["warranty", "guarantee", "garantie", "garantía", "garantia", "保証", "garantia", "warranties"]
    private nonisolated static let returnKeywords = ["return", "refund", "exchange", "returns"]

    /// Matches a keyword as a whole word, so "Subtotal" is not read as "total". CJK text has no
    /// word boundaries, so those keywords fall back to a plain substring test.
    nonisolated static func contains(keyword: String, in line: String) -> Bool {
        guard keyword.allSatisfy({ $0.isASCII }) else { return line.contains(keyword) }
        guard let regex = try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: keyword) + "\\b") else {
            return line.contains(keyword)
        }
        return regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
    }

    /// True when a line carries any total label, paid or not. Used to keep total lines out of
    /// the merchant and product guesses.
    nonisolated static func isTotalLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return strongTotalKeywords.contains { contains(keyword: $0, in: lower) }
            || totalKeywords.contains { contains(keyword: $0, in: lower) }
    }

    /// Which class of total label a line carries: 0 for an unambiguous "grand total", 1 for a
    /// plainer one, and `nil` when the line is not the amount paid at all.
    nonisolated static func totalTier(of line: String) -> Int? {
        let lower = line.lowercased()
        guard !totalNoise.contains(where: { contains(keyword: $0, in: lower) }) else { return nil }
        if strongTotalKeywords.contains(where: { contains(keyword: $0, in: lower) }) { return 0 }
        if totalKeywords.contains(where: { contains(keyword: $0, in: lower) }) { return 1 }
        return nil
    }

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
    /// The amount the customer actually paid.
    ///
    /// A receipt mentions "total" many times — Subtotal, Total savings, Total items, Total tax —
    /// so candidates are ranked: an unambiguous label ("Grand Total") beats a plain one, a later
    /// line beats an earlier one (receipts print the amount paid last), and only then does the
    /// larger amount win.
    nonisolated func parseTotal(lines: [String]) -> Int? {
        var best: (tier: Int, index: Int, amount: Double)?
        for (index, line) in lines.enumerated() {
            guard let tier = Self.totalTier(of: line) else { continue }
            guard let amount = allNumbers(in: line).max() else { continue }
            let beatsCurrent: Bool
            if let current = best {
                beatsCurrent = tier < current.tier
                    || (tier == current.tier && index > current.index)
                    || (tier == current.tier && index == current.index && amount > current.amount)
            } else {
                beatsCurrent = true
            }
            if beatsCurrent { best = (tier, index, amount) }
        }
        guard let total = best?.amount else { return nil }
        return minorUnits(total, currencyCode: parseCurrencyFromAmountText(lines.joined(separator: "\n")) ?? "")
    }

    /// Every number-looking run on a line, with its separators: "1,299.50", "1.299,50",
    /// "1,29,950.00" (Indian lakh grouping), "1 299,50" (French) or a plain "129950".
    /// The old pattern stopped at "1,29" on a lakh number and reported 1.29.
    nonisolated func allNumbers(in s: String) -> [Double] {
        let pattern = #"[0-9]+(?:[.,\s][0-9]+)*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = s as NSString
        return regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            parseAmount(ns.substring(with: $0.range))
        }
    }

    /// Handles "1.299,50" (EU) and "1,299.50" (US) and "1299.50" and "1,29,950.00" (lakh).
    nonisolated func parseAmount(_ raw: String) -> Double? {
        let s = raw.replacingOccurrences(of: " ", with: "")
        if let lastDot = s.lastIndex(of: "."), let lastComma = s.lastIndex(of: ",") {
            if lastComma > lastDot {
                // Decimal comma, dot as thousands: 1.299,50
                return Double(s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
            }
            // Decimal dot, comma as thousands: 1,299.50 / 1,29,950.00
            return Double(s.replacingOccurrences(of: ",", with: ""))
        }
        if s.contains(",") {
            // No dot at all, so a trailing two-digit group is the decimal part and every other
            // group is thousands: "49,90" is 49.90, "1,29,950" is 129950.
            let groups = s.split(separator: ",")
            if let tail = groups.last, tail.count == 2 {
                return Double(groups.dropLast().joined() + "." + tail)
            }
            return Double(s.replacingOccurrences(of: ",", with: ""))
        }
        return Double(s)
    }

    nonisolated func minorUnits(_ amount: Double, currencyCode: String) -> Int {
        Money.minorUnits(amount, currencyCode: currencyCode)
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
            !Self.isTotalLine(line) &&
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
            !Self.isTotalLine(line) &&
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
