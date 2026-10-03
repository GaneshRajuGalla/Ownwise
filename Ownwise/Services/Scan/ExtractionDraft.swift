import Foundation

/// Sendable value type crossing actor boundaries from the scan pipeline to the UI.
struct ExtractionDraft: Sendable {
    var name: String = ""
    var merchant: String = ""
    var brand: String = ""
    var modelNumber: String = ""
    var serialNumber: String = ""
    var category: ItemCategory = .other
    var purchaseDate: Date?
    var totalMinor: Int?
    var currencyCode: String = ""
    var warrantyMonths: Int?
    var returnDays: Int?
    var orderNumber: String = ""
    var ocrText: String = ""
    var fieldsFromAI: Set<Field> = []

    enum Field: String, Sendable, Hashable {
        case name, merchant, brand, modelNumber, serialNumber, category, purchaseDate, total, currency, warranty, returnWindow, orderNumber
    }
}
