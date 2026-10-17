import Foundation
import SwiftData

/// A versioned, self-describing copy of everything Ownwise stores — receipts and photos included.
///
/// The file is plain JSON so it can be read, and `formatVersion` lets a later release refuse a
/// backup it cannot understand rather than importing it half-way.
struct BackupService {
    /// Bump only when the shape changes in a way older code cannot read.
    static let formatVersion = 1

    var now: Date = .now

    // MARK: - Format

    struct Backup: Codable, Equatable {
        var formatVersion: Int
        var exportedAt: Date
        var items: [ItemRecord]
    }

    struct ItemRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var brand: String
        var modelNumber: String
        var serialNumber: String
        var category: String
        var purchaseDate: Date
        var priceMinor: Int?
        var currencyCode: String
        var merchant: String
        var orderNumber: String
        var taxID: String
        var supportPhone: String
        var notes: String
        var customReminderDate: Date?
        var createdAt: Date
        var coverages: [CoverageRecord]
        var attachments: [AttachmentRecord]
    }

    struct CoverageRecord: Codable, Equatable {
        var id: UUID
        var kind: String
        var provider: String
        var startDate: Date
        var endDate: Date
        var serviceIntervalMonths: Int?
        var lastServiceDate: Date?
        var contact: String
        var reminderLeadDays: [Int]?
    }

    struct AttachmentRecord: Codable, Equatable {
        var id: UUID
        var kind: String
        var contentType: String
        var ocrText: String
        var createdAt: Date
        var fileData: Data?
    }

    enum BackupError: LocalizedError, Equatable {
        case notABackup
        case newerVersion(Int)

        var errorDescription: String? {
            switch self {
            case .notABackup:
                String(localized: "That file isn't an Ownwise backup.")
            case .newerVersion(let version):
                String(localized: "This backup was made by a newer version of Ownwise (format \(version)). Update the app, then try again.")
            }
        }
    }

    // MARK: - Writing

    var backupFileName: String {
        "Ownwise Backup \(now.formatted(.iso8601.year().month().day())).json"
    }

    func backup(items: [Item]) -> Backup {
        Backup(formatVersion: Self.formatVersion, exportedAt: now, items: items.map(record(for:)))
    }

    func data(items: [Item]) throws -> Data {
        try encoder.encode(backup(items: items))
    }

    func file(items: [Item]) throws -> ExportFile {
        try ExportService().write(try data(items: items), named: backupFileName)
    }

    func record(for item: Item) -> ItemRecord {
        ItemRecord(
            id: item.id,
            name: item.name,
            brand: item.brand,
            modelNumber: item.modelNumber,
            serialNumber: item.serialNumber,
            category: item.categoryRaw,
            purchaseDate: item.purchaseDate,
            priceMinor: item.priceMinor,
            currencyCode: item.currencyCode,
            merchant: item.merchant,
            orderNumber: item.orderNumber,
            taxID: item.taxID,
            supportPhone: item.supportPhone,
            notes: item.notes,
            customReminderDate: item.customReminderDate,
            createdAt: item.createdAt,
            coverages: (item.coverages ?? []).map { coverage in
                CoverageRecord(
                    id: coverage.id, kind: coverage.kindRaw, provider: coverage.provider,
                    startDate: coverage.startDate, endDate: coverage.endDate,
                    serviceIntervalMonths: coverage.serviceIntervalMonths,
                    lastServiceDate: coverage.lastServiceDate, contact: coverage.contact,
                    reminderLeadDays: coverage.reminderLeadDays
                )
            },
            attachments: (item.attachments ?? []).map { attachment in
                AttachmentRecord(
                    id: attachment.id, kind: attachment.kindRaw, contentType: attachment.contentType,
                    ocrText: attachment.ocrText, createdAt: attachment.createdAt,
                    fileData: attachment.fileData
                )
            }
        )
    }

    // MARK: - Reading

    func decode(_ data: Data) throws -> Backup {
        guard let backup = try? decoder.decode(Backup.self, from: data) else { throw BackupError.notABackup }
        guard backup.formatVersion <= Self.formatVersion else {
            throw BackupError.newerVersion(backup.formatVersion)
        }
        return backup
    }

    /// Replaces the library with the backup. Replace rather than merge, so restoring the same
    /// file twice cannot double every item; the caller confirms with the user first.
    @MainActor
    func restore(_ backup: Backup, into context: ModelContext) throws {
        guard backup.formatVersion <= Self.formatVersion else {
            throw BackupError.newerVersion(backup.formatVersion)
        }
        for existing in try context.fetch(FetchDescriptor<Item>()) { context.delete(existing) }
        for record in backup.items {
            let item = Item(name: record.name)
            item.id = record.id
            item.brand = record.brand
            item.modelNumber = record.modelNumber
            item.serialNumber = record.serialNumber
            item.categoryRaw = record.category
            item.purchaseDate = record.purchaseDate
            item.priceMinor = record.priceMinor
            item.currencyCode = record.currencyCode
            item.merchant = record.merchant
            item.orderNumber = record.orderNumber
            item.taxID = record.taxID
            item.supportPhone = record.supportPhone
            item.notes = record.notes
            item.customReminderDate = record.customReminderDate
            item.createdAt = record.createdAt
            item.coverages = record.coverages.map(coverage(from:))
            item.attachments = record.attachments.map(attachment(from:))
            context.insert(item)
        }
        context.saveOrReport()
    }

    private func coverage(from record: CoverageRecord) -> Coverage {
        let coverage = Coverage(kind: CoverageKind(rawValue: record.kind) ?? .manufacturer,
                                start: record.startDate, end: record.endDate)
        coverage.id = record.id
        coverage.provider = record.provider
        coverage.serviceIntervalMonths = record.serviceIntervalMonths
        coverage.lastServiceDate = record.lastServiceDate
        coverage.contact = record.contact
        coverage.reminderLeadDays = record.reminderLeadDays
        return coverage
    }

    private func attachment(from record: AttachmentRecord) -> Attachment {
        let attachment = Attachment(kind: AttachmentKind(rawValue: record.kind) ?? .photo,
                                    data: Data(), contentType: record.contentType)
        attachment.id = record.id
        // Assign after init so "no bytes saved" stays nil rather than becoming empty data.
        attachment.fileData = record.fileData
        attachment.ocrText = record.ocrText
        attachment.createdAt = record.createdAt
        return attachment
    }

    // MARK: - Coding

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
