import Foundation
import FoundationModels

@Generable enum GenCategory { case appliance, electronics, mobile, computer, furniture, vehicle, other }

@Generable(description: "Purchase facts found on a receipt")
struct ReceiptFields {
    @Guide(description: "Seller name, empty if absent") var merchant: String
    @Guide(description: "Main product bought, short") var productName: String
    @Guide(description: "Brand, empty if absent") var brand: String
    @Guide(description: "Model number, empty if absent") var modelNumber: String
    @Guide(description: "Purchase date yyyy-MM-dd, empty if absent") var purchaseDate: String
    @Guide(description: "Grand total paid, 0 if absent") var total: Double
    @Guide(description: "ISO 4217 currency code, empty if unclear") var currencyCode: String
    @Guide(description: "Warranty months stated, 0 if none", .range(0...120)) var warrantyMonths: Int
    @Guide(description: "Return window days stated, 0 if none", .range(0...365)) var returnDays: Int
    var category: GenCategory
}

actor AIExtractor {
    private let instructions = """
    Extract purchase facts from receipt OCR text. Use only facts present in the text. \
    Never guess. Use empty string or 0 when a fact is missing.
    """
    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func extract(_ ocrText: String) async throws -> ReceiptFields? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: instructions)
        let prompt = String(ocrText.prefix(3000))
        return try await session.respond(to: prompt, generating: ReceiptFields.self).content
    }

    /// 20 s race: AI or nil.
    func extractWithTimeout(_ ocrText: String) async -> ReceiptFields? {
        await withTaskGroup(of: ReceiptFields?.self) { group in
            group.addTask { try? await self.extract(ocrText) }
            group.addTask {
                try? await Task.sleep(for: .seconds(20))
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first ?? nil
        }
    }
}
