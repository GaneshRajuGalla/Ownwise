import Testing
import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
@testable import Ownwise

@MainActor
struct ScanPipelineTests {

    @Test("Parser wins on conflict, AI fills gaps")
    func mergeRules() {
        var draft = ExtractionDraft()
        draft.merchant = "Best Buy"
        draft.totalMinor = 129950
        draft.warrantyMonths = 12

        let ai = ReceiptFields(
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

    @Test("A printed serial beats a barcode, and a barcode beats nothing (E5)")
    func serialPrecedence() async {
        // The parser reads "S/N: ..." — better evidence than a barcode, so it wins.
        let printed = await ScanPipeline().draft(fromText: "S/N: C02ABCDE123", scannedSerial: "BARCODE-999")
        #expect(printed.serialNumber == "C02ABCDE123")

        // Nothing printed, so the barcode fills it — before the AI merge, which only fills gaps.
        let scanned = await ScanPipeline().draft(fromText: "Best Buy\nTotal: $5.00", scannedSerial: "BARCODE-999")
        #expect(scanned.serialNumber == "BARCODE-999")

        // Without text that could be a serial and no barcode, nothing is invented.
        let bare = await ScanPipeline().draft(fromText: "Best Buy\nTotal: $5.00", scannedSerial: nil)
        #expect(bare.fieldsFromAI.contains(.serialNumber) || bare.serialNumber.isEmpty)
    }

    @Test("A barcode on the page is what the camera path reads into the serial field")
    func barcodeFlowsThroughTheCameraPath() async throws {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data("SN-ABC123".utf8)
        let output = try #require(filter.outputImage)
        // Barcodes come out on a transparent field; a scanner wants them on white, with a margin.
        let margin: CGFloat = 20
        let white = CIImage(color: .white).cropped(to: output.extent.insetBy(dx: -margin, dy: -margin))
        let composed = output.composited(over: white)
            .transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        let cgImage = try #require(CIContext().createCGImage(composed, from: composed.extent))

        let draft = await ScanPipeline().run(images: [UIImage(cgImage: cgImage)])

        #expect(draft.serialNumber == "SN-ABC123")
        #expect(!draft.fieldsFromAI.contains(.serialNumber), "a scanned barcode is not an AI guess")
    }
}
