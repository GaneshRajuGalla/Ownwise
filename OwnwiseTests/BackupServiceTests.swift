import Testing
import Foundation
import SwiftData
@testable import Ownwise

@MainActor
struct BackupServiceTests {

    @Test("A backup round-trips every field, coverage and receipt")
    func roundTripsEverything() throws {
        let source = Persistence.makeContainer(inMemory: true)
        let sourceContext = ModelContext(source)
        let item = Item(name: "Dishwasher")
        item.brand = "Bosch"
        item.modelNumber = "SMV4H"
        item.serialNumber = "SN-12345678"
        item.category = .appliance
        item.priceMinor = 74999
        item.currencyCode = "EUR"
        item.merchant = "Media Markt"
        item.orderNumber = "MM-9911"
        item.taxID = "DE123456789"
        item.supportPhone = "+49 30 123456"
        item.notes = "Extended warranty bought"
        item.customReminderDate = Date(timeIntervalSince1970: 1_800_000_000)
        item.purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        item.createdAt = Date(timeIntervalSince1970: 1_700_000_500)
        let coverage = Coverage(kind: .manufacturer,
                                start: Date(timeIntervalSince1970: 1_700_000_000),
                                end: Date(timeIntervalSince1970: 1_730_000_000))
        coverage.provider = "Bosch"
        coverage.contact = "0800 1234"
        coverage.reminderLeadDays = [30, 7]
        let attachment = Attachment(kind: .receipt, data: Data([0xDE, 0xAD, 0xBE, 0xEF]), contentType: "public.jpeg")
        attachment.ocrText = "Media Markt"
        item.coverages = [coverage]
        item.attachments = [attachment]
        sourceContext.insert(item)
        sourceContext.saveOrReport()

        let service = BackupService()
        let data = try service.data(items: [item])

        let destination = Persistence.makeContainer(inMemory: true)
        let destinationContext = ModelContext(destination)
        // Something is already there, to prove a restore replaces rather than merges.
        destinationContext.insert(Item(name: "Old kettle"))
        destinationContext.saveOrReport()

        try service.restore(service.decode(data), into: destinationContext)

        let restored = try destinationContext.fetch(FetchDescriptor<Item>())
        #expect(restored.count == 1)
        let copy = try #require(restored.first)
        #expect(copy.name == "Dishwasher")
        #expect(copy.brand == "Bosch")
        #expect(copy.modelNumber == "SMV4H")
        #expect(copy.serialNumber == "SN-12345678")
        #expect(copy.categoryRaw == item.categoryRaw)
        #expect(copy.priceMinor == 74999)
        #expect(copy.currencyCode == "EUR")
        #expect(copy.merchant == "Media Markt")
        #expect(copy.orderNumber == "MM-9911")
        #expect(copy.taxID == "DE123456789")
        #expect(copy.supportPhone == "+49 30 123456")
        #expect(copy.notes == "Extended warranty bought")
        #expect(copy.customReminderDate == item.customReminderDate)
        #expect(copy.purchaseDate == item.purchaseDate)
        #expect(copy.createdAt == item.createdAt)
        #expect(copy.id == item.id)

        let copyCoverage = try #require((copy.coverages ?? []).first)
        #expect(copyCoverage.kind == .manufacturer)
        #expect(copyCoverage.provider == "Bosch")
        #expect(copyCoverage.contact == "0800 1234")
        #expect(copyCoverage.reminderLeadDays == [30, 7])
        #expect(copyCoverage.endDate == coverage.endDate)

        let copyAttachment = try #require((copy.attachments ?? []).first)
        #expect(copyAttachment.kindRaw == AttachmentKind.receipt.rawValue)
        #expect(copyAttachment.fileData == Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(copyAttachment.ocrText == "Media Markt")
        #expect(copyAttachment.contentType == "public.jpeg")
    }

    @Test("A file that is not a backup is refused instead of wiping the library")
    func refusesForeignData() throws {
        let service = BackupService()
        #expect(throws: BackupService.BackupError.notABackup) {
            try service.decode(Data("{\"hello\":\"world\"}".utf8))
        }
    }

    @Test("A backup from a newer format is refused, not half-imported")
    func refusesNewerFormat() throws {
        let service = BackupService()
        let nextVersion = BackupService.formatVersion + 1
        let future = BackupService.Backup(formatVersion: nextVersion, exportedAt: .now, items: [])
        let data = try JSONEncoder().encode(future)
        #expect(throws: BackupService.BackupError.newerVersion(nextVersion)) {
            try service.decode(data)
        }
    }

    @Test("A receipt with no saved bytes keeps its nil rather than becoming empty data")
    func preservesMissingAttachmentData() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let item = Item(name: "Kettle")
        let attachment = Attachment(kind: .receipt, data: Data(), contentType: "public.jpeg")
        attachment.fileData = nil
        item.attachments = [attachment]
        context.insert(item)

        let service = BackupService()
        try service.restore(service.decode(try service.data(items: [item])), into: context)

        let copy = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect((copy.attachments ?? []).first?.fileData == nil)
    }
}
