import Testing
import Foundation
import SwiftData
import UIKit
@testable import Ownwise

/// Turning a shared-in receipt into a library item (E1). The text cases are exact; the image and PDF
/// cases only assert that nothing is lost, because what Vision reads back is not ours to predict.
@MainActor
struct InboxImporterTests {

    private let receiptText = """
    Best Buy
    Order #BBY01-2345678
    OLED TV 55 inch LG
    Date: 09/15/2026
    Grand Total: $1,299.50
    1 Year Limited Warranty
    30-day return policy
    """

    private func tempInbox() throws -> (inbox: SharedInbox, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "InboxImporterTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (SharedInbox(root: root), root)
    }

    private func context() -> ModelContext {
        ModelContext(Persistence.makeContainer(inMemory: true))
    }

    @Test("Shared receipt text becomes a full item, and the text is kept")
    func importsText() async throws {
        let (inbox, _) = try tempInbox()
        let context = context()
        try inbox.enqueue(SharedInbox.Entry(title: "Best Buy order", text: receiptText,
                                            url: "https://bestbuy.com/orders/1234"))

        let imported = await InboxImporter.importAll(from: inbox, into: context)

        #expect(imported == 1)
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        let item = try #require(items.first)
        // The same parse the camera path uses, so the fields match a scan of the same receipt.
        #expect(item.name == "OLED TV 55 inch LG")
        #expect(item.merchant == "Best Buy")
        #expect(item.priceMinor == 129950)
        #expect(item.currencyCode == "USD")
        #expect(item.orderNumber == "BBY01-2345678")
        #expect(Set((item.coverages ?? []).map(\.kind)) == [.manufacturer, .returnWindow])
        // Nothing is thrown away: the link and the text are kept on the item.
        #expect(item.notes.contains("https://bestbuy.com/orders/1234"))
        #expect(item.notes.contains("Grand Total: $1,299.50"))
        #expect(inbox.pendingFolders().isEmpty)
    }

    @Test("A shared image becomes an item with the image kept as its receipt")
    func importsImage() async throws {
        let (inbox, _) = try tempInbox()
        let context = context()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60),
                                            format: .default()).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
        try inbox.enqueue(SharedInbox.Entry(title: "Amazon order"),
                          files: [("receipt.jpg", try #require(image.jpegData(compressionQuality: 0.8)))])

        let imported = await InboxImporter.importAll(from: inbox, into: context)

        #expect(imported == 1)
        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        let attachment = try #require((item.attachments ?? []).first)
        #expect(attachment.kindRaw == AttachmentKind.receipt.rawValue)
        #expect(attachment.fileData?.isEmpty == false)
        // A blank image reads as nothing, so the share's own title names the item.
        #expect(item.name.isEmpty == false)
        #expect(inbox.pendingFolders().isEmpty)
    }

    @Test("A shared PDF is rendered and imported like a photo of the same receipt")
    func importsPDF() async throws {
        let (inbox, _) = try tempInbox()
        let context = context()
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 300)
        let pdf = UIGraphicsPDFRenderer(bounds: bounds, format: UIGraphicsPDFRendererFormat()).pdfData { ctx in
            ctx.beginPage()
            UIColor.white.setFill()
            ctx.fill(bounds)
        }
        try inbox.enqueue(SharedInbox.Entry(title: "Currys invoice"),
                          files: [("invoice.pdf", pdf)])

        let imported = await InboxImporter.importAll(from: inbox, into: context)

        #expect(imported == 1, "a PDF share must not be a dead end")
        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect((item.attachments ?? []).isEmpty == false)
        #expect(inbox.pendingFolders().isEmpty)
    }

    @Test("A file the app cannot read is kept aside, never deleted")
    func unsupportedFileIsKept() async throws {
        let (inbox, root) = try tempInbox()
        let context = context()
        try inbox.enqueue(SharedInbox.Entry(title: "Something"),
                          files: [("archive.zip", Data([0x50, 0x4B, 0x03, 0x04]))])

        let imported = await InboxImporter.importAll(from: inbox, into: context)

        #expect(imported == 0)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(inbox.pendingFolders().isEmpty)
        let kept = root.appending(path: "Failed")
        let keptFolders = try FileManager.default.contentsOfDirectory(atPath: kept.path)
        #expect(keptFolders.count == 1, "the payload stays on disk for the user")
    }

    @Test("An entry whose manifest cannot be read is set aside too")
    func corruptManifestIsKept() async throws {
        let (inbox, root) = try tempInbox()
        let context = context()
        let folder = root.appending(path: "Pending/broken", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appending(path: SharedInbox.manifestName))

        let imported = await InboxImporter.importAll(from: inbox, into: context)

        #expect(imported == 0)
        #expect(inbox.pendingFolders().isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: root.appending(path: "Failed/broken/\(SharedInbox.manifestName)").path))
    }

    @Test("At the free limit the rest waits in the inbox instead of being dropped")
    func stopsAtTheFreeLimit() async throws {
        let (inbox, _) = try tempInbox()
        let context = context()
        for index in 1...3 {
            try inbox.enqueue(SharedInbox.Entry(title: "Order \(index)", text: receiptText))
        }

        let imported = await InboxImporter.importAll(from: inbox, into: context) { count in
            count < 2
        }

        #expect(imported == 2)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 2)
        // Not quarantined: it is waiting for room (an upgrade, or a deletion), not broken.
        #expect(inbox.pendingFolders().count == 1)
    }
}
