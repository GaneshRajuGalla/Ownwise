import Testing
import Foundation
import PDFKit
import SwiftData
import UIKit
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

    @Test("CSV file is written to disk with a dated name")
    func csvFile() throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-04T12:00:00Z")!
        let file = try ExportService(now: now).csvFile(items: [Item(name: "TV")])
        #expect(file.url.lastPathComponent == "Ownwise Items 2026-03-04.csv")
        #expect(try Data(contentsOf: file.url).count > 0)
    }

    @Test("Paper size: US Letter for US/CA, A4 elsewhere",
          arguments: [("en_US", true), ("fr_CA", true), ("de_DE", false), ("en_IN", false), ("ja_JP", false)])
    func paperSize(locale: String, isLetter: Bool) {
        let expected = isLetter ? ExportService.usLetter : ExportService.a4
        #expect(ExportService(locale: Locale(identifier: locale)).paperSize() == expected)
    }

    @Test("Coverage left counts whole days and reports expiry")
    func coverageLeft() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .gmt
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 18))!
        let svc = ExportService(now: now, calendar: cal)
        let future = Coverage(kind: .manufacturer, start: now, end: cal.date(from: DateComponents(year: 2026, month: 1, day: 20, hour: 1))!)
        let past = Coverage(kind: .manufacturer, start: now, end: cal.date(from: DateComponents(year: 2026, month: 1, day: 9))!)
        #expect(svc.daysLeft(until: future.endDate) == 10)
        #expect(svc.coverageLeft(future) == "10 days left")
        #expect(svc.coverageLeft(past) == "Expired")
    }

    @Test("Claim Pack file name strips path-unsafe characters")
    func fileName() {
        #expect(ExportService().claimPackFileName(for: Item(name: "55\" TV/Stand")) == "Claim Pack - 55  TV Stand.pdf")
        #expect(ExportService().claimPackFileName(for: Item(name: "")) == "Claim Pack - Item.pdf")
    }

    @Test("Claim Pack PDF has selectable text and matches locale paper size")
    func pdfText() throws {
        let item = Item(name: "OLED TV")
        item.brand = "LG"; item.serialNumber = "SN-998877"
        let data = ExportService(locale: Locale(identifier: "de_DE")).makeClaimPackPDF(item: item)
        let doc = try #require(PDFDocument(data: data))
        #expect(doc.pageCount == 1)
        let text = doc.string ?? ""
        #expect(text.contains("OLED TV"))
        #expect(text.contains("SN-998877"))
        #expect(doc.page(at: 0)?.bounds(for: .mediaBox).size == ExportService.a4)
    }

    @Test("Claim Pack PDF adds one page per receipt / warranty card image, receipts first")
    func pdfAttachments() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let item = Item(name: "Washer")
        context.insert(item)
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60)).jpegData(withCompressionQuality: 0.8) { ctx in
            UIColor.gray.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }
        let card = Attachment(kind: .warrantyCard, data: jpeg, contentType: "public.jpeg")
        let receipt = Attachment(kind: .receipt, data: jpeg, contentType: "public.jpeg")
        let broken = Attachment(kind: .photo, data: Data([0, 1, 2]), contentType: "public.jpeg")
        item.attachments = [card, receipt, broken]

        let svc = ExportService()
        #expect(svc.attachmentImages(of: item).map(\.kind) == [.receipt, .warrantyCard])
        let doc = try #require(PDFDocument(data: svc.makeClaimPackPDF(item: item)))
        #expect(doc.pageCount == 3)
    }

    @Test("Writing empty data fails instead of sharing a blank file")
    func emptyWriteThrows() {
        #expect(throws: (any Error).self) { try ExportService().write(Data(), named: "x.csv") }
    }

    @Test("A resale pack is the same facts under its own name (E9)")
    func resalePack() throws {
        let item = Item(name: "Kettle")
        item.serialNumber = "SN-1234"

        #expect(ExportService().claimPackFileName(for: item, kind: .handover) == "Resale Pack - Kettle.pdf")
        let doc = try #require(PDFDocument(data: ExportService().makeClaimPackPDF(item: item, kind: .handover)))
        let text = doc.string ?? ""
        #expect(text.contains("Resale Pack"))
        #expect(text.contains("SN-1234"), "a buyer gets the serial number")
        #expect(text.contains("Proof of purchase"), "and is told what the document is for")
    }

    @Test("Inventory report: one page of totals, then a page per chunk of items (E4)")
    func inventoryReportPaginates() throws {
        let items = (0..<45).map { index -> Item in
            let item = Item(name: "Item \(index)")
            item.priceMinor = 1000
            return item
        }

        let doc = try #require(PDFDocument(data: ExportService().makeInventoryReportPDF(items: items)))

        // 45 rows at 20 a page: the first page (totals) plus three item pages.
        #expect(doc.pageCount == 4)
        let first = doc.page(at: 0)?.string ?? ""
        let second = doc.page(at: 1)?.string ?? ""
        let last = doc.page(at: 3)?.string ?? ""
        #expect(first.contains("45 items"))
        #expect(second.contains("Items 1 of 3"))
        #expect(last.contains("Items 3 of 3"))
        // Nothing is silently dropped: every item appears somewhere.
        let all = (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined()
        for index in [0, 20, 44] {
            #expect(all.contains("Item \(index)"))
        }
    }

    @Test("Inventory report names a file after its date and never mixes currencies (E4, E10)")
    func inventoryReportFile() throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-04T12:00:00Z")!
        let usd = Item(name: "TV"); usd.priceMinor = 129_950; usd.currencyCode = "USD"
        let eur = Item(name: "Kettle"); eur.priceMinor = 4_999; eur.currencyCode = "EUR"

        let svc = ExportService(now: now)
        let file = try svc.inventoryReportFile(items: [usd, eur])
        #expect(file.url.lastPathComponent == "Ownwise Inventory 2026-03-04.pdf")

        let doc = try #require(PDFDocument(data: svc.makeInventoryReportPDF(items: [usd, eur])))
        let text = try #require(doc.page(at: 0)?.string)
        #expect(text.contains("Recorded value"))
        // Two currencies means two subtotals, each formatted by the same `Money` the app uses.
        #expect(text.contains(Money.formatted(129_950, currencyCode: "USD")))
        #expect(text.contains(Money.formatted(4_999, currencyCode: "EUR")))
        // …and never the sum of two currencies, which would be a wrong number in a document someone
        // hands to an insurer.
        #expect(!text.contains(Money.formatted(134_949, currencyCode: "USD")))
    }
}
