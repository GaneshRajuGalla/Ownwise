import SwiftData
import Foundation
import OSLog

enum Persistence {
    private static let log = Logger(subsystem: "com.ownwise.Ownwise", category: "Persistence")

    /// True when the on-disk store could not be opened and was moved aside, so the app could
    /// start. Settings reads this to tell the user instead of pretending their data is intact.
    static var didRecoverStore = false

    /// Where the unreadable store was moved to. The original file is preserved, never deleted.
    static var recoveredStoreFolder: URL?

    /// True when iCloud was requested but could not be opened, so the local store was used.
    static var didFallBackToLocalStore = false

    /// Opens the store. A store that cannot be read must never crash-loop the app: it is moved
    /// aside (with its `-shm`/`-wal` sidecars) and a fresh one is created in its place.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let cloud = cloudKitDatabase()
        let config = ModelConfiguration(schema: schema,
                                        isStoredInMemoryOnly: inMemory,
                                        cloudKitDatabase: cloud.database)
        do {
            return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config)
        } catch {
            log.error("ModelContainer failed to open: \(error, privacy: .public)")
            // iCloud can be unavailable for reasons that have nothing to do with the store: no
            // account signed in, the entitlement not provisioned yet, or no network. Retry the
            // *same* store locally before assuming the store itself is damaged.
            if !inMemory, cloud.enabled {
                let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
                if let container = try? ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: local) {
                    log.notice("iCloud was unavailable, so the local store was opened instead.")
                    didFallBackToLocalStore = true
                    return container
                }
            }
            if !inMemory, let folder = setAside(storeAt: config.url) {
                do {
                    let container = try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config)
                    didRecoverStore = true
                    recoveredStoreFolder = folder
                    return container
                } catch {
                    log.error("A rebuilt container still failed to open: \(error, privacy: .public)")
                }
            }
            return inMemoryFallback(schema: schema)
        }
    }

    /// The CloudKit database to open with, and whether CloudKit was actually requested.
    private static func cloudKitDatabase() -> (database: ModelConfiguration.CloudKitDatabase, enabled: Bool) {
        guard let identifier = SyncSettings.containerIdentifier, SyncSettings.isEnabled else {
            return (.none, false)
        }
        return (.private(identifier), true)
    }

    /// Moves an unreadable store and its `-shm`/`-wal` sidecars into `Recovered/<timestamp>/`.
    /// Returns the folder they were moved to, or `nil` if even that failed.
    /// Internal rather than private so the recovery path can be tested without damaging the
    /// real store.
    static func setAside(storeAt url: URL) -> URL? {
        let fileManager = FileManager.default
        let folder = url.deletingLastPathComponent()
            .appending(path: "Recovered")
            .appending(path: "\(Int(Date.now.timeIntervalSince1970))")
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for suffix in ["", "-shm", "-wal"] {
                let source = URL(fileURLWithPath: url.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                try fileManager.moveItem(at: source, to: folder.appending(path: source.lastPathComponent))
            }
            log.notice("Unreadable store moved to \(folder.path(percentEncoded: false), privacy: .public)")
            return folder
        } catch {
            log.error("Could not set the unreadable store aside: \(error, privacy: .public)")
            return nil
        }
    }

    /// Last resort, so the app opens even if writes cannot be persisted, rather than not opening.
    private static func inMemoryFallback(schema: Schema) -> ModelContainer {
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do { return try ModelContainer(for: schema, configurations: memory) }
        catch { fatalError("SwiftData cannot start even in memory: \(error)") }
    }

    /// Seeds sample data for previews / `-seedSampleData` launch arg.
    @MainActor
    static func seedSampleData(into context: ModelContext) {
        let tv = Item(name: "55\" OLED TV")
        tv.brand = "LG"; tv.category = .electronics; tv.merchant = "Best Buy"
        tv.priceMinor = 129950; tv.currencyCode = "USD"
        tv.purchaseDate = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .now
        tv.coverages = [Coverage(kind: .manufacturer, start: tv.purchaseDate, end: Calendar.current.date(byAdding: .year, value: 1, to: tv.purchaseDate) ?? .now)]

        let laptop = Item(name: "MacBook Air 13\"")
        laptop.brand = "Apple"; laptop.category = .computer; laptop.serialNumber = "C02ABCDE123"
        laptop.purchaseDate = Calendar.current.date(byAdding: .month, value: -6, to: .now) ?? .now
        laptop.coverages = [Coverage(kind: .returnWindow, start: laptop.purchaseDate, end: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now)]

        let washer = Item(name: "Washer")
        washer.brand = "Samsung"; washer.category = .appliance
        let svc = Coverage(kind: .servicePlan, start: washer.purchaseDate, end: .distantFuture)
        svc.serviceIntervalMonths = 3
        svc.lastServiceDate = Calendar.current.date(byAdding: .month, value: -4, to: .now)
        washer.coverages = [svc]

        for item in [tv, laptop, washer] { context.insert(item) }
        context.saveOrReport()
    }
}
