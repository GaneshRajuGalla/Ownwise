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
    var orderNumber: String = ""
    var fieldsFromAI: Set<ExtractionDraft.Field> = []
    var ocrText: String = ""
    var attachmentData: Data?
    var attachmentType: String = "public.jpeg"

    init(draft: ExtractionDraft) {
        name = draft.name
        merchant = draft.merchant
        brand = draft.brand
        modelNumber = draft.modelNumber
        serialNumber = draft.serialNumber
        category = draft.category
        purchaseDate = draft.purchaseDate ?? .now
        if let t = draft.totalMinor {
            totalText = String(format: "%.2f", Double(t) / 100)
        }
        currencyCode = draft.currencyCode
        if let w = draft.warrantyMonths { warrantyMonthsText = String(w) }
        if let r = draft.returnDays { returnDaysText = String(r) }
        orderNumber = draft.orderNumber
        fieldsFromAI = draft.fieldsFromAI
        ocrText = draft.ocrText
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
        item.currencyCode = currencyCode.isEmpty ? (Locale.current.currency?.identifier ?? "USD") : currencyCode
        if let total = Double(totalText.replacingOccurrences(of: ",", with: ".")) {
            item.priceMinor = Int((total * 100).rounded())
        }
        item.orderNumber = orderNumber
        var coverages: [Coverage] = []
        if let r = Int(returnDaysText), r > 0 {
            coverages.append(Coverage(kind: .returnWindow, start: purchaseDate, end: Calendar.current.date(byAdding: .day, value: r, to: purchaseDate) ?? purchaseDate))
        }
        if let w = Int(warrantyMonthsText), w > 0 {
            coverages.append(Coverage(kind: .manufacturer, start: purchaseDate, end: Calendar.current.date(byAdding: .month, value: w, to: purchaseDate) ?? purchaseDate))
        }
        item.coverages = coverages
        if let data = attachmentData {
            item.attachments = [Attachment(kind: .receipt, data: data, contentType: attachmentType)]
        }
        context.insert(item)
        try? context.save()
    }
}
