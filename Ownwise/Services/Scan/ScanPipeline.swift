import Foundation
import CoreGraphics

/// Baseline parse, then AI fills only missing fields (parser wins on conflict).
struct ScanPipeline: Sendable {
    var ocr: OCRService = OCRService()
    var parser: ReceiptParser = ReceiptParser()
    var ai: AIExtractor = AIExtractor()

    func run(images: [CGImage]) async -> ExtractionDraft {
        // OCR all pages concurrently.
        let texts: [String] = await withTaskGroup(of: String.self) { group in
            for img in images {
                group.addTask { (try? await self.ocr.recognize(img).text) ?? "" }
            }
            var out: [String] = []
            for await t in group { out.append(t) }
            return out
        }
        let joined = texts.joined(separator: "\n")
        let parsed = parser.parse(joined)
        var draft = ExtractionDraft(
            merchant: parsed.merchant ?? "",
            brand: "",
            modelNumber: "",
            serialNumber: parsed.serialNumber ?? "",
            category: .other,
            purchaseDate: parsed.purchaseDate,
            totalMinor: parsed.totalMinor,
            currencyCode: parsed.currencyCode ?? "",
            warrantyMonths: parsed.warrantyMonths,
            returnDays: parsed.returnDays,
            orderNumber: parsed.orderNumber ?? "",
            ocrText: joined
        )
        draft.name = parsed.productName ?? ""

        if let aiFields = await ai.extractWithTimeout(joined) {
            merge(into: &draft, ai: aiFields)
        }
        return draft
    }

    nonisolated func merge(into draft: inout ExtractionDraft, ai: ReceiptFields) {
        if draft.name.isEmpty, !ai.productName.isEmpty { draft.name = ai.productName; draft.fieldsFromAI.insert(.name) }
        if draft.merchant.isEmpty, !ai.merchant.isEmpty { draft.merchant = ai.merchant; draft.fieldsFromAI.insert(.merchant) }
        if draft.brand.isEmpty, !ai.brand.isEmpty { draft.brand = ai.brand; draft.fieldsFromAI.insert(.brand) }
        if draft.modelNumber.isEmpty, !ai.modelNumber.isEmpty { draft.modelNumber = ai.modelNumber; draft.fieldsFromAI.insert(.modelNumber) }
        if draft.purchaseDate == nil, !ai.purchaseDate.isEmpty {
            if let d = ISO8601DateFormatter().date(from: ai.purchaseDate + "T00:00:00Z") ?? DateFormatter.iso.date(from: ai.purchaseDate) {
                draft.purchaseDate = d
                draft.fieldsFromAI.insert(.purchaseDate)
            }
        }
        if draft.totalMinor == nil, ai.total > 0 {
            draft.totalMinor = Int((ai.total * 100).rounded())
            draft.fieldsFromAI.insert(.total)
        }
        if draft.currencyCode.isEmpty, !ai.currencyCode.isEmpty { draft.currencyCode = ai.currencyCode; draft.fieldsFromAI.insert(.currency) }
        if draft.warrantyMonths == nil, ai.warrantyMonths > 0 { draft.warrantyMonths = ai.warrantyMonths; draft.fieldsFromAI.insert(.warranty) }
        if draft.returnDays == nil, ai.returnDays > 0 { draft.returnDays = ai.returnDays; draft.fieldsFromAI.insert(.returnWindow) }
        if draft.category == .other {
            draft.category = {
                switch ai.category {
                case .appliance: .appliance
                case .electronics: .electronics
                case .mobile: .mobile
                case .computer: .computer
                case .furniture: .furniture
                case .vehicle: .vehicle
                case .other: .other
                }
            }()
            draft.fieldsFromAI.insert(.category)
        }
    }
}

private extension DateFormatter {
    nonisolated static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
