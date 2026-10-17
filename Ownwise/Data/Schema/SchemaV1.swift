import Foundation
import SwiftData

/// v1: the schema the app first shipped with.
///
/// **Each schema version deliberately repeats every model.** SwiftData matches versions by their
/// declared model types, so letting two `VersionedSchema`s share one model class is what breaks
/// migration — the duplication in this folder is the pattern, not an accident, and must not be
/// "de-duplicated".
///
/// Adding a V3:
/// 1. Copy `SchemaV2.swift` to `SchemaV3.swift`, set `versionIdentifier` to `Schema.Version(3, 0, 0)`
///    and make the model change there.
/// 2. Add a stage to `MigrationPlan.swift`.
/// 3. Point `Persistence.makeContainer` at `SchemaV3.self`.
/// Keep every property optional or defaulted, every relationship optional, and use no
/// `@Attribute(.unique)` — CloudKit requires all three.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Item.self, Coverage.self, Attachment.self] }

    @Model final class Item {
        var id: UUID = UUID()
        var name: String = ""
        var brand: String = ""
        var modelNumber: String = ""
        var serialNumber: String = ""
        var categoryRaw: String = ItemCategory.appliance.rawValue
        var purchaseDate: Date = Date.now
        var priceMinor: Int? = nil
        var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
        var merchant: String = ""
        var orderNumber: String = ""
        var taxID: String = ""
        var supportPhone: String = ""
        var notes: String = ""
        /// One-off reminder the user picked (Ownwise Pro).
        var customReminderDate: Date? = nil
        var createdAt: Date = Date.now
        @Relationship(deleteRule: .cascade, inverse: \Coverage.item) var coverages: [Coverage]? = []
        @Relationship(deleteRule: .cascade, inverse: \Attachment.item) var attachments: [Attachment]? = []

        var category: ItemCategory {
            get { ItemCategory(rawValue: categoryRaw) ?? .other }
            set { categoryRaw = newValue.rawValue }
        }
        init(name: String) { self.name = name }
    }

    @Model final class Coverage {
        var id: UUID = UUID()
        var kindRaw: String = CoverageKind.manufacturer.rawValue
        var provider: String = ""
        var startDate: Date = Date.now
        var endDate: Date = Date.now
        var serviceIntervalMonths: Int? = nil
        var lastServiceDate: Date? = nil
        var contact: String = ""
        var item: Item?

        var kind: CoverageKind {
            get { CoverageKind(rawValue: kindRaw) ?? .manufacturer }
            set { kindRaw = newValue.rawValue }
        }
        var nextServiceDate: Date? {
            guard let m = serviceIntervalMonths, m > 0 else { return nil }
            return Calendar.current.date(byAdding: .month, value: m, to: lastServiceDate ?? startDate)
        }
        init(kind: CoverageKind, start: Date, end: Date) { kindRaw = kind.rawValue; startDate = start; endDate = end }
    }

    @Model final class Attachment {
        var id: UUID = UUID()
        var kindRaw: String = AttachmentKind.receipt.rawValue
        @Attribute(.externalStorage) var fileData: Data? = nil
        var contentType: String = "public.jpeg"
        var ocrText: String = ""
        var createdAt: Date = Date.now
        var item: Item?
        init(kind: AttachmentKind, data: Data, contentType: String) {
            kindRaw = kind.rawValue; fileData = data; self.contentType = contentType
        }
    }
}

// The app-wide `Item` / `Coverage` / `Attachment` aliases live in SchemaV2.swift,
// which is the current version. v1 stays only so the migration can read old stores.
