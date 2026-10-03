import Testing
import Foundation
@testable import Ownwise

@MainActor
struct ScanPipelineTests {

    @Test("Parser wins on conflict, AI fills gaps")
    func mergeRules() {
        var draft = ExtractionDraft()
        draft.merchant = "Best Buy"
        draft.totalMinor = 129950
        draft.warrantyMonths = 12

        var ai = ReceiptFields(
            merchant: "AI Merchant",
            productName: "OLED TV",
            brand: "LG",
            modelNumber: "OLED55",
            purchaseDate: "2026-09-15",
            total: 999.99,
            currencyCode: "USD",
            warrantyMonths: 24,
            returnDays: 30,
            category: .electronics
        )

        let pipeline = ScanPipeline()
        pipeline.merge(into: &draft, ai: ai)

        #expect(draft.merchant == "Best Buy")       // parser wins
        #expect(draft.totalMinor == 129950)           // parser wins
        #expect(draft.warrantyMonths == 12)           // parser wins
        #expect(draft.brand == "LG")                  // AI fills gap
        #expect(draft.modelNumber == "OLED55")
        #expect(draft.name == "OLED TV")
        #expect(draft.returnDays == 30)
        #expect(draft.currencyCode == "USD")
        #expect(draft.category == .electronics)
        #expect(draft.fieldsFromAI.contains(.brand))
        #expect(!draft.fieldsFromAI.contains(.name) == false) // name was blank → AI filled
    }
}
