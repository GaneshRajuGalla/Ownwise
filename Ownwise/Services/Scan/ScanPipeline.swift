import Foundation
import UIKit

/// Baseline parse, then AI fills only missing fields (parser wins on conflict).
///
/// `run` is `nonisolated` on purpose. The project defaults to `MainActor` isolation, so without
/// saying so out loud every step here — decoding the picked pages, JPEG-compressing them for
/// storage, Vision OCR, the parse and the AI merge — would run on the main actor and a
/// multi-page scan would visibly hitch the UI.
struct ScanPipeline: Sendable {
    var ocr: OCRService = OCRService()
    var parser: ReceiptParser = ReceiptParser()
    var ai: AIExtractor = AIExtractor()

    nonisolated func run(images: [UIImage]) async -> ExtractionDraft {
        let pageImages = images.compactMap(\.cgImage)
        // OCR all pages concurrently, then put them back in page order for the parser.
        let texts = await orderedConcurrentMap(pageImages) { img in
            (try? await self.ocr.recognize(img).text) ?? ""
        }
        let joined = texts.joined(separator: "\n")
        var draft = await draft(fromText: joined)
        // Compressing the pages is part of the heavy work, so it belongs off the main actor too.
        draft.pageImages = images.compactMap { $0.jpegData(compressionQuality: 0.7) }
        return draft
    }

    /// The parse-and-fill half of the pipeline, for text that is already in hand: OCR output from a
    /// scan, or the text a share extension handed over (E1). Kept in one place so both paths read a
    /// receipt the same way.
    nonisolated func draft(fromText text: String) async -> ExtractionDraft {
        let parsed = parser.parse(text)
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
            ocrText: text
        )
        draft.name = parsed.productName ?? ""
        // The parser already reads a VAT/GST number; carry it through instead of dropping it (H5).
        draft.taxID = parsed.taxID ?? ""

        if let aiFields = await ai.extractWithTimeout(text) {
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
            draft.totalMinor = Money.minorUnits(ai.total, currencyCode: draft.currencyCode.isEmpty ? ai.currencyCode : draft.currencyCode)
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
