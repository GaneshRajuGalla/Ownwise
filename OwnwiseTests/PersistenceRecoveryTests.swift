import Testing
import Foundation
@testable import Ownwise

@MainActor
struct PersistenceRecoveryTests {

    @Test("An unreadable store is moved aside with its sidecars, never deleted")
    func movesStoreAndSidecarsAside() throws {
        let folder = URL.temporaryDirectory.appending(path: "ownwise-recovery-\(UUID().uuidString)")
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: folder) }

        let store = folder.appending(path: "default.store")
        try Data("not a database".utf8).write(to: store)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: store.path + "-wal"))
        try Data("shm".utf8).write(to: URL(fileURLWithPath: store.path + "-shm"))
        let bystander = folder.appending(path: "keep-me.txt")
        try Data("unrelated".utf8).write(to: bystander)

        let movedTo = try #require(Persistence.setAside(storeAt: store))

        #expect(!fileManager.fileExists(atPath: store.path))
        #expect(!fileManager.fileExists(atPath: store.path + "-wal"))
        #expect(!fileManager.fileExists(atPath: store.path + "-shm"))
        // The store is preserved rather than thrown away, and nothing unrelated comes along.
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            #expect(fileManager.fileExists(atPath: movedTo.appending(path: name).path))
        }
        #expect(fileManager.fileExists(atPath: bystander.path))
        #expect(movedTo.deletingLastPathComponent().lastPathComponent == "Recovered")
    }

    @Test("A store that does not exist yet still reports where it would be set aside")
    func absentStoreStillReportsFolder() {
        let folder = URL.temporaryDirectory.appending(path: "ownwise-recovery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let movedTo = Persistence.setAside(storeAt: folder.appending(path: "default.store"))
        #expect(movedTo != nil)
    }
}
