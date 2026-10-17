import Foundation

/// The hand-off point between a share extension and the app (E1).
///
/// An extension cannot open the app's SwiftData store, and should not try: two processes writing one
/// SQLite file is how a library gets corrupted. Instead the extension writes a small JSON manifest
/// plus the files the user shared into a shared folder, and the app drains that folder when it comes
/// to the front (`InboxImporter`). The app stays the only writer of the store.
///
/// **Inert until an App Group is configured.** `SharedInbox.default` uses the container named by the
/// `OwnwiseAppGroupID` key in Info.plist. With no key — or with the capability not yet granted —
/// there is no container, so every operation here is a no-op and the app behaves exactly as it does
/// today. See `docs/share-extension.md` for the capability steps.
struct SharedInbox: Sendable {

    /// One thing the user shared, as the extension writes it.
    struct Entry: Codable, Sendable, Equatable {
        var id: UUID = UUID()
        /// What the system called it: a file name, a page title, an item's title.
        var title: String = ""
        /// Text that came with it; the only parsing input when there is no file.
        var text: String = ""
        /// A web address, kept so a receipt can be traced back to the order.
        var url: String = ""
        /// Files sitting beside the manifest, by name.
        var fileNames: [String] = []
    }

    /// The folder the inbox lives in, or nil when no App Group is configured.
    let root: URL?

    static let appGroupIDInfoKey = "OwnwiseAppGroupID"
    static let manifestName = "manifest.json"

    /// The inbox in the app's shared container; inert when there is no container.
    static var `default`: SharedInbox {
        let groupID = Bundle.main.object(forInfoDictionaryKey: appGroupIDInfoKey) as? String
        let container = groupID.flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
        return SharedInbox(root: container?.appending(path: "SharedInbox", directoryHint: .isDirectory))
    }

    /// For tests, previews, and any caller that owns its own folder.
    init(root: URL?) { self.root = root }

    var isAvailable: Bool { root != nil }

    private var pendingDirectory: URL? {
        root?.appending(path: "Pending", directoryHint: .isDirectory)
    }
    private var failedDirectory: URL? {
        root?.appending(path: "Failed", directoryHint: .isDirectory)
    }
    private var stagingDirectory: URL? {
        root?.appending(path: "Staging", directoryHint: .isDirectory)
    }

    // MARK: Producer — what the extension calls

    /// Writes one share and returns its id (nil when there is no inbox to write to).
    ///
    /// Staged then moved, so the entry appears in `Pending` complete: the app can never read a
    /// half-written manifest or a missing file.
    @discardableResult
    func enqueue(_ entry: Entry, files: [(name: String, data: Data)] = []) throws -> UUID? {
        guard let pendingDirectory, let stagingDirectory else { return nil }
        let fm = FileManager.default
        var entry = entry
        entry.fileNames = files.map(\.name)

        let staging = stagingDirectory.appending(path: entry.id.uuidString, directoryHint: .isDirectory)
        if fm.fileExists(atPath: staging.path) { try fm.removeItem(at: staging) }
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        for file in files {
            try file.data.write(to: staging.appending(path: file.name), options: .atomic)
        }
        let manifest = try JSONEncoder().encode(entry)
        try manifest.write(to: staging.appending(path: Self.manifestName), options: .atomic)

        try fm.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        let destination = pendingDirectory.appending(path: entry.id.uuidString, directoryHint: .isDirectory)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: staging, to: destination)
        return entry.id
    }

    // MARK: Consumer — what the app calls

    /// Entry folders waiting to be imported, in a stable order.
    func pendingFolders() -> [URL] {
        guard let pendingDirectory else { return [] }
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: pendingDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return folders.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The manifest in a folder, or nil when it cannot be read.
    func entry(in folder: URL) -> Entry? {
        guard let data = try? Data(contentsOf: folder.appending(path: Self.manifestName)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    /// The files a manifest lists, in the order it lists them. Missing files are skipped.
    func files(of entry: Entry, in folder: URL) -> [(name: String, url: URL)] {
        entry.fileNames.compactMap { name in
            let url = folder.appending(path: name)
            return FileManager.default.fileExists(atPath: url.path) ? (name, url) : nil
        }
    }

    /// Removes an entry that has been imported. Only ever called on success, so a failed entry is
    /// never deleted.
    func remove(folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Sets an entry aside instead of deleting it: a receipt the user chose to share is kept on disk
    /// (and in their backup) even when this app cannot read it.
    func quarantine(folder: URL) {
        guard let failedDirectory else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: failedDirectory, withIntermediateDirectories: true)
        let destination = failedDirectory.appending(path: folder.lastPathComponent, directoryHint: .isDirectory)
        if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
        try? fm.moveItem(at: folder, to: destination)
    }
}
