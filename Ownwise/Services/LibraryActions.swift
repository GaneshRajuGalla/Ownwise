import Foundation
import SwiftData

/// The mutations a library performs, in one place instead of inside the views that trigger them.
///
/// Views keep what is theirs — dismissing, presenting, alerting — and hand the *meaning* of an
/// action ("delete this item", "mark this coverage serviced") to these functions, which is the
/// layering README §4 asks for and what makes the behaviour unit-testable (H3).
///
/// Each function owns its own save, so a caller cannot forget one. Rescheduling reminders stays at
/// the call site, because the scheduler is the view's own dependency.
@MainActor
enum LibraryActions {

    /// Deletes an item. Its coverages, receipts and photos go with it through the cascade rules, so
    /// call this only after the user has confirmed.
    static func delete(_ item: Item, in context: ModelContext) {
        context.delete(item)
        context.saveOrReport()
    }

    /// Deletes one coverage, unlinking it from its item first so the relationship array cannot keep
    /// a reference to a deleted row.
    static func delete(_ coverage: Coverage, of item: Item, in context: ModelContext) {
        item.coverages = (item.coverages ?? []).filter { $0.id != coverage.id }
        context.delete(coverage)
        context.saveOrReport()
    }

    /// Marks a service plan serviced on `date`, which starts its next interval.
    static func markServiced(_ coverage: Coverage, on date: Date = .now, in context: ModelContext) {
        coverage.lastServiceDate = date
        context.saveOrReport()
    }

    static func addAttachment(data: Data, kind: AttachmentKind, contentType: String,
                              to item: Item, in context: ModelContext) {
        let attachment = Attachment(kind: kind, data: data, contentType: contentType)
        item.attachments = (item.attachments ?? []) + [attachment]
        context.saveOrReport()
    }

    static func delete(_ attachment: Attachment, of item: Item, in context: ModelContext) {
        item.attachments = (item.attachments ?? []).filter { $0.id != attachment.id }
        context.delete(attachment)
        context.saveOrReport()
    }
}
