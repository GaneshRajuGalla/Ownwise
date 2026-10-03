import Foundation
import Vision

struct OCRResult: Sendable { var text: String }

struct OCRService: Sendable {
    func recognize(_ image: CGImage) async throws -> OCRResult {
        let request = RecognizeDocumentsRequest()
        let observations = try await request.perform(on: image)
        guard let doc = observations.first?.document else { return OCRResult(text: "") }
        return OCRResult(text: doc.paragraphs.map(\.transcript).joined(separator: "\n"))
    }
}
