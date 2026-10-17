import Foundation

/// The small file a widget reads (E2), and the app writes.
///
/// A widget cannot open the app's SwiftData store — and must not: the app stays the only writer. So
/// the app writes what a widget needs into the App Group and the widget only reads. That keeps the
/// widget target's surface tiny: this file and nothing else of the app's.
///
/// Pure Foundation on purpose, so the future widget target can add it without SwiftData.
/// `SnapshotBuilder` (app side) is what fills it in from the library.
///
/// **Inert without an App Group**, exactly like `SharedInbox`.
nonisolated struct SharedSnapshot: Sendable {

    /// One line of the widget: something whose cover is running out, and when.
    struct Entry: Codable, Sendable, Equatable, Identifiable {
        /// The coverage's id, so a tap can open the right item later.
        var id: UUID
        /// The item this belongs to.
        var itemID: UUID
        var name: String
        /// What is running out, already in the user's language (the snapshot is short-lived; it is
        /// rewritten whenever the app is opened).
        var kind: String
        /// When it ends — or, for a service plan, when the next service is due.
        var endDate: Date
    }

    struct Value: Codable, Sendable, Equatable {
        var generatedAt: Date
        var entries: [Entry]

        static let empty = Value(generatedAt: .distantPast, entries: [])
    }

    /// How many items a widget shows before it runs out of room.
    static let maxEntries = 5
    static let fileName = "expiring.json"

    /// The folder the snapshot lives in, or nil when there is no App Group.
    let directory: URL?

    static var `default`: SharedSnapshot { SharedSnapshot(directory: AppGroup.directory("Widget")) }

    /// For tests and any caller that owns its own folder.
    init(directory: URL?) { self.directory = directory }

    var isAvailable: Bool { directory != nil }

    private var fileURL: URL? { directory?.appending(path: Self.fileName) }

    /// Writes the snapshot, or does nothing when there is no App Group to write to.
    func write(_ value: Value) {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: fileURL, options: .atomic)
        } catch {
            // A widget's data going stale is not worth taking the app down for; it rewrites on the
            // next change anyway.
        }
    }

    /// The snapshot, or nil when there is none or it cannot be read (a widget shows its placeholder
    /// then, which is the right answer).
    func read() -> Value? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }
}
