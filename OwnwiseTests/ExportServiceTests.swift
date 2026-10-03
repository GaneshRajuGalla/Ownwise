import Testing
import Foundation
@testable import Ownwise

@MainActor
struct ExportServiceTests {

    @Test("CSV escapes commas, quotes and newlines (RFC-4180)")
    func csvEscaping() {
        let svc = ExportService()
        #expect(svc.csvField("plain") == "plain")
        #expect(svc.csvField("a,b") == "\"a,b\"")
        #expect(svc.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(svc.csvField("line1\nline2") == "\"line1\nline2\"")
    }

    @Test("CSV round-trip row count")
    func csvRows() {
        let item = Item(name: "TV")
        item.brand = "LG"; item.merchant = "Best Buy"
        let data = ExportService().makeCSV(items: [item])
        let text = String(data: data, encoding: .utf8)!
        #expect(text.split(separator: "\r\n").count == 2)
        #expect(text.contains("TV"))
    }

    @Test("Claim Pack PDF is non-empty")
    func pdfNonEmpty() {
        let item = Item(name: "TV")
        item.brand = "LG"
        let data = ExportService().makeClaimPackPDF(item: item)
        #expect(data.count > 1000)
        #expect(String(data: data.prefix(8), encoding: .ascii)?.contains("%PDF") == true)
    }
}
