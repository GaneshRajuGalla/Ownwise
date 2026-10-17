import Testing
import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
@testable import Ownwise

/// Reading a serial off a barcode (E5).
///
/// The barcode images are generated here, so this proves the whole path — generate, detect, decode —
/// rather than trusting a checked-in fixture whose provenance nobody can check.
struct BarcodeServiceTests {

    /// Barcodes come out as black bars on a transparent field: a scanner wants them on white, with a
    /// quiet margin, which is also what a real label has.
    private func render(_ output: CIImage?, scale: CGFloat, margin: CGFloat = 20) throws -> CGImage {
        let image = try #require(output)
        let white = CIImage(color: .white).cropped(to: image.extent.insetBy(dx: -margin, dy: -margin))
        let composed = image.composited(over: white)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return try #require(CIContext().createCGImage(composed, from: composed.extent))
    }

    private func code128(_ message: String) throws -> CGImage {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(message.utf8)
        return try render(filter.outputImage, scale: 4)
    }

    private func qr(_ message: String) throws -> CGImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(message.utf8)
        return try render(filter.outputImage, scale: 10)
    }

    @Test("A Code 128 label is read back exactly")
    func code128RoundTrip() throws {
        #expect(try BarcodeService().read(code128("SN-ABC123")) == ["SN-ABC123"])
    }

    @Test("A QR code is read, because a serial is often one")
    func qrRoundTrip() throws {
        #expect(try BarcodeService().read(qr("S/N 99887766")) == ["S/N 99887766"])
    }

    @Test("A page with no barcode reads as nothing, not as a failure")
    func noBarcode() throws {
        let blank = try render(CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 300, height: 200)),
                               scale: 1)
        #expect(try BarcodeService().read(blank).isEmpty)
    }

    @Test("Product barcodes are not read: an EAN identifies a model, not the item in your hand")
    func productSymbologiesAreExcluded() {
        let productCodes: [VNBarcodeSymbology] = [.ean8, .ean13, .upce, .i2of5, .i2of5Checksum, .itf14]
        for symbology in productCodes {
            #expect(!BarcodeService.symbologies.contains(symbology),
                    "\(symbology.rawValue) is a shared product code, not a serial")
        }
        for symbology in [VNBarcodeSymbology.code128, .qr, .dataMatrix, .pdf417, .aztec] {
            #expect(BarcodeService.symbologies.contains(symbology), "\(symbology.rawValue) is read")
        }
    }
}
