import Foundation
import SwiftData
import Observation

/// Editable state behind ReviewView.
@Observable
@MainActor
final class ReviewModel {
    var name: String = ""
    var merchant: String = ""
    var brand: String = ""
    var modelNumber: String = ""
    var serialNumber: String = ""
    var category: ItemCategory = .other
    var purchaseDate: Date = .now
    var totalText: String = ""
    var currencyCode: String = ""
    var warrantyMonthsText: String = ""
    var returnDaysText: String = ""
    /// Reminder timing chosen on the review screen; nil keeps the smart default.
    var returnLeads: [Int]?
    var warrantyLeads: [Int]?
    var orderNumber: String = ""
    var taxID: String = ""
    /// Not shown on the review screen: where a shared-in item came from (E1), so nothing a user
    /// shared is thrown away.
    var notes: String = ""
    var fieldsFromAI: Set<ExtractionDraft.Field> = []
    var ocrText: String = ""
    var pageImages: [Data] = []

    init(draft: ExtractionDraft) {
        name = draft.name
        merchant = draft.merchant
        brand = draft.brand
        modelNumber = draft.modelNumber
        serialNumber = draft.serialNumber
        category = draft.category
        purchaseDate = draft.purchaseDate ?? .now
        currencyCode = draft.currencyCode
        if let t = draft.totalMinor {
            totalText = Money.plainString(t, currencyCode: draft.currencyCode)
        }
        if let w = draft.warrantyMonths { warrantyMonthsText = String(w) }
        if let r = draft.returnDays { returnDaysText = String(r) }
        orderNumber = draft.orderNumber
        taxID = draft.taxID
        fieldsFromAI = draft.fieldsFromAI
        ocrText = draft.ocrText
        pageImages = draft.pageImages
    }

    func save(into context: ModelContext) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Never save a filename-looking or empty name; fall back to merchant.
        let finalName: String
        if trimmedName.isEmpty || trimmedName.contains(".png") || trimmedName.contains(".jpg") || trimmedName.contains(".pdf") {
            finalName = merchant.isEmpty ? "Scanned item" : merchant
        } else {
            finalName = trimmedName
        }
        let item = Item(name: finalName)
        item.merchant = merchant
        item.brand = brand
        item.modelNumber = modelNumber
        item.serialNumber = serialNumber
        item.category = category
        item.purchaseDate = purchaseDate
        item.currencyCode = currencyCode.isEmpty ? (Locale.current.currency?.identifier ?? "USD") : currencyCode.uppercased()
        // One parser everywhere (ReceiptParser also accepts "1,299.50" and "1.299,50").
        if let total = ReceiptParser().parseAmount(totalText), total >= 0 {
            item.priceMinor = Money.minorUnits(total, currencyCode: item.currencyCode)
        }
        item.orderNumber = orderNumber
        item.taxID = taxID
        item.notes = notes
        // Coverage construction lives in one place (H4).
        var coverages: [Coverage] = []
        if let r = Int(returnDaysText), r > 0 {
            let coverage = CoverageBuilder.make(kind: .returnWindow, start: purchaseDate, length: r)
            coverage.reminderLeadDays = returnLeads
            coverages.append(coverage)
        }
        if let w = Int(warrantyMonthsText), w > 0 {
            let coverage = CoverageBuilder.make(kind: .manufacturer, start: purchaseDate, length: w)
            coverage.reminderLeadDays = warrantyLeads
            coverages.append(coverage)
        }
        item.coverages = coverages
        item.attachments = pageImages.map { data in
            let attachment = Attachment(kind: .receipt, data: data, contentType: "public.jpeg")
            attachment.ocrText = ocrText
            return attachment
        }
        context.insert(item)
        context.saveOrReport()
    }
}

extension ReviewModel {
    /// Whole-number days/months typed on the review screen; 0 means "not set".
    var returnDays: Int { Int(returnDaysText.trimmingCharacters(in: .whitespaces)) ?? 0 }
    var warrantyMonths: Int { Int(warrantyMonthsText.trimmingCharacters(in: .whitespaces)) ?? 0 }
}
