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
}
