import Foundation
import Vision

/// Reads barcodes off the same pages the OCR reads (E5).
///
/// The serial number is the field people actually need at claim time, and copying it off a label is
/// miserable, so the scan flow looks for a barcode as well as text.
///
/// **Product barcodes are deliberately not read.** An EAN/UPC identifies a *model* — every one of that
/// model shares it — so putting one in the serial field would be a confident lie, and the field is the
/// one thing a claim actually turns on. What is read is the free-form symbologies a manufacturer uses
/// for a serial: Code 128/39/93, Codabar, QR, Data Matrix, PDF417 and Aztec.
///
/// `nonisolated`: Vision runs off the main actor, alongside OCR.
nonisolated struct BarcodeService: Sendable {

    /// Symbologies that carry manufacturer-printed text rather than a shared product code.
    static let symbologies: [VNBarcodeSymbology] = [.code128, .code39, .code39Checksum, .code93,
                                                    .codabar, .qr, .dataMatrix, .pdf417, .aztec]

    /// Every payload found, deduplicated, in Vision's order.
    nonisolated func read(_ image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = Self.symbologies
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
        var seen = Set<String>()
        return payloads.filter { seen.insert($0).inserted }
    }
}
