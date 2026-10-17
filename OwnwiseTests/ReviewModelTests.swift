import Testing
import Foundation
import SwiftData
@testable import Ownwise

@MainActor
struct ReviewModelTests {

    @Test("Saving a scan keeps every page as a receipt attachment with its OCR text")
    func savesScannedPages() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var draft = ExtractionDraft()
        draft.name = "OLED TV"
        draft.ocrText = "Best Buy\nTotal: $10.00"
        draft.pageImages = [Data([0xFF, 0xD8, 0x01]), Data([0xFF, 0xD8, 0x02])]

        ReviewModel(draft: draft).save(into: context)

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        let attachments = item.attachments ?? []
        #expect(attachments.count == 2)
        #expect(attachments.allSatisfy { $0.kindRaw == AttachmentKind.receipt.rawValue })
        #expect(attachments.allSatisfy { $0.ocrText == draft.ocrText })
    }

    @Test("Manual entry (no pages) saves without attachments")
    func manualEntryHasNoAttachments() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var draft = ExtractionDraft()
        draft.name = "Kettle"

        ReviewModel(draft: draft).save(into: context)

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect((item.attachments ?? []).isEmpty)
    }

    @Test("A typed total survives review in either separator style")
    func parsesTypedTotal() throws {
        // "1,299.50" used to become 1.2995 (the comma was swapped for a point) and the price was lost.
        let cases: [(text: String, minor: Int)] = [("1,299.50", 129950), ("1.299,50", 129950),
                                                   ("1299.50", 129950), ("1299", 129900)]
        for testCase in cases {
            let container = Persistence.makeContainer(inMemory: true)
            let context = ModelContext(container)
            var draft = ExtractionDraft()
            draft.name = "Dishwasher"
            draft.currencyCode = "USD"
            let model = ReviewModel(draft: draft)
            model.totalText = testCase.text

            model.save(into: context)

            let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
            #expect(item.priceMinor == testCase.minor, "\(testCase.text) should parse to \(testCase.minor)")
        }
    }

    @Test("An empty total leaves the price unset instead of guessing zero")
    func emptyTotalLeavesPriceUnset() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var draft = ExtractionDraft()
        draft.name = "Kettle"
        draft.currencyCode = "USD"
        let model = ReviewModel(draft: draft)
        model.totalText = ""

        model.save(into: context)

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.priceMinor == nil)
    }
}
