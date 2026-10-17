import Testing
import Foundation
@testable import Ownwise

/// The share-extension hand-off contract (E1), exercised on a folder this test owns — no App Group
/// required, which is exactly how the feature behaves until the capability is granted.
struct SharedInboxTests {

    private func tempInbox() throws -> (inbox: SharedInbox, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "SharedInboxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (SharedInbox(root: root), root)
    }

    @Test("A queued share comes back out whole, files included")
    func roundTrip() throws {
        let (inbox, _) = try tempInbox()
        #expect(inbox.isAvailable)

        let id = try inbox.enqueue(SharedInbox.Entry(title: "Order 1234", text: "Total: $10.00", url: "https://example.com"),
                                   files: [("receipt.jpg", Data([0x01, 0x02]))])
        #expect(id != nil)

        let folders = inbox.pendingFolders()
        #expect(folders.count == 1)
        let entry = try #require(inbox.entry(in: folders[0]))
        #expect(entry.title == "Order 1234")
        #expect(entry.text == "Total: $10.00")
        #expect(entry.url == "https://example.com")
        #expect(entry.fileNames == ["receipt.jpg"])

        let files = inbox.files(of: entry, in: folders[0])
        #expect(files.map(\.name) == ["receipt.jpg"])
        #expect(try Data(contentsOf: files[0].url) == Data([0x01, 0x02]))

        inbox.remove(folder: folders[0])
        #expect(inbox.pendingFolders().isEmpty)
    }

    @Test("With no App Group there is no inbox, and nothing throws")
    func inertWithoutAContainer() throws {
        let inbox = SharedInbox(root: nil)
        #expect(inbox.isAvailable == false)
        #expect(try inbox.enqueue(SharedInbox.Entry(title: "Order")) == nil)
        #expect(inbox.pendingFolders().isEmpty)
        // These must be harmless no-ops rather than force-unwraps.
        inbox.remove(folder: URL(fileURLWithPath: "/nonexistent"))
        inbox.quarantine(folder: URL(fileURLWithPath: "/nonexistent"))
    }

    @Test("Quarantining keeps the payload on disk instead of deleting it")
    func quarantineKeepsThePayload() throws {
        let (inbox, root) = try tempInbox()
        try inbox.enqueue(SharedInbox.Entry(title: "Order"), files: [("receipt.jpg", Data([0x09]))])
        let folder = try #require(inbox.pendingFolders().first)

        inbox.quarantine(folder: folder)

        #expect(inbox.pendingFolders().isEmpty)
        let kept = root.appending(path: "Failed/\(folder.lastPathComponent)/receipt.jpg")
        #expect(FileManager.default.fileExists(atPath: kept.path))
        #expect(try Data(contentsOf: kept) == Data([0x09]))
    }

    @Test("A manifest that cannot be read is reported as unreadable, not guessed at")
    func unreadableManifest() throws {
        let (inbox, root) = try tempInbox()
        let folder = root.appending(path: "Pending/broken", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appending(path: SharedInbox.manifestName))

        #expect(inbox.entry(in: folder) == nil)
    }
}
