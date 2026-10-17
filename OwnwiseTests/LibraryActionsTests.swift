import Testing
import Foundation
import SwiftData
@testable import Ownwise

/// The library mutations the views delegate to (H3).
@MainActor
struct LibraryActionsTests {

    private func container() -> ModelContainer { Persistence.makeContainer(inMemory: true) }

    @Test("Deleting an item takes its coverages and receipts with it, as the dialog promises")
    func deleteItemCascades() throws {
        let container = container()
        let context = ModelContext(container)
        let item = Item(name: "Kettle")
        item.coverages = [Coverage(kind: .manufacturer, start: .now, end: .now)]
        item.attachments = [Attachment(kind: .receipt, data: Data([0x01]), contentType: "public.jpeg")]
        context.insert(item)
        context.saveOrReport()

        LibraryActions.delete(item, in: context)

        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Coverage>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Ownwise.Attachment>()) == 0)
    }

    @Test("Deleting one coverage unlinks it from its item and leaves the entry gone")
    func deleteOneCoverage() throws {
        let container = container()
        let context = ModelContext(container)
        let item = Item(name: "Kettle")
        let keep = Coverage(kind: .manufacturer, start: .now, end: .now)
        let remove = Coverage(kind: .returnWindow, start: .now, end: .now)
        item.coverages = [keep, remove]
        context.insert(item)
        context.saveOrReport()

        LibraryActions.delete(remove, of: item, in: context)

        #expect((item.coverages ?? []).map(\.id) == [keep.id])
        #expect(try context.fetchCount(FetchDescriptor<Coverage>()) == 1)
    }

    @Test("Marking a plan serviced moves the next service one interval on")
    func markServiced() throws {
        let container = container()
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let coverage = Coverage(kind: .servicePlan, start: start, end: .distantFuture)
        coverage.serviceIntervalMonths = 3
        coverage.lastServiceDate = start
        let item = Item(name: "Washer")
        item.coverages = [coverage]
        context.insert(item)
        context.saveOrReport()

        let today = Date(timeIntervalSince1970: 1_780_000_000)
        LibraryActions.markServiced(coverage, on: today, in: context)

        #expect(coverage.lastServiceDate == today)
        #expect(coverage.nextServiceDate == Calendar.current.date(byAdding: .month, value: 3, to: today))
    }

    @Test("Adding a receipt stores its bytes, kind and content type")
    func addAttachment() throws {
        let container = container()
        let context = ModelContext(container)
        let item = Item(name: "Kettle")
        context.insert(item)
        context.saveOrReport()

        LibraryActions.addAttachment(data: Data([0xAB, 0xCD]), kind: .warrantyCard,
                                     contentType: "public.jpeg", to: item, in: context)

        let stored = try #require((item.attachments ?? []).first)
        #expect(stored.kindRaw == AttachmentKind.warrantyCard.rawValue)
        #expect(stored.fileData == Data([0xAB, 0xCD]))
        #expect(stored.contentType == "public.jpeg")
    }

    @Test("Deleting one attachment leaves the others")
    func deleteOneAttachment() throws {
        let container = container()
        let context = ModelContext(container)
        let item = Item(name: "Kettle")
        let keep = Attachment(kind: .receipt, data: Data([0x01]), contentType: "public.jpeg")
        let remove = Attachment(kind: .photo, data: Data([0x02]), contentType: "public.jpeg")
        item.attachments = [keep, remove]
        context.insert(item)
        context.saveOrReport()

        LibraryActions.delete(remove, of: item, in: context)

        #expect((item.attachments ?? []).map(\.id) == [keep.id])
        #expect(try context.fetchCount(FetchDescriptor<Ownwise.Attachment>()) == 1)
    }
}
