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
}
