import Foundation
import SwiftData
import UIKit
import PDFKit

/// Turns shared-in entries into library items (E1).
///
/// Runs when the app comes to the front, so the work happens at a moment the user can see the
/// result. It reuses the scan path exactly — `ScanPipeline` for OCR/parse/AI, `ReviewModel.save` for
/// the field mapping — rather than mapping fields a second time and letting the two drift apart
/// (the H4 lesson).
///
/// Nothing is ever deleted on failure: an entry that cannot be read is moved to the inbox's
/// `Failed` folder, and an entry that cannot be *imported* (the free limit) simply stays pending.
@MainActor
enum InboxImporter {

    /// Imports everything waiting, stopping early when the library is full.
    ///
    /// - Parameter canAddItem: whether one more item is allowed, given the current count. The free
    ///   limit has to be asked here too, or sharing a receipt would become a way around it.
    /// - Returns: how many items were created.
    @discardableResult
    static func importAll(from inbox: SharedInbox, into context: ModelContext,
                          canAddItem: (Int) -> Bool = { _ in true }) async -> Int {
        var imported = 0
        for folder in inbox.pendingFolders() {
            guard let entry = inbox.entry(in: folder) else {
                // Unreadable manifest: keep it (it is the user's receipt) and stop retrying it.
                inbox.quarantine(folder: folder)
                continue
            }
            let count = (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
            guard canAddItem(count) else { break }
            if await importOne(entry, files: inbox.files(of: entry, in: folder), into: context) {
                inbox.remove(folder: folder)
                imported += 1
            } else {
                inbox.quarantine(folder: folder)
            }
        }
        return imported
    }

    /// One entry. Returns false only when nothing readable arrived at all.
    private static func importOne(_ entry: SharedInbox.Entry,
                                  files: [(name: String, url: URL)],
                                  into context: ModelContext) async -> Bool {
        var images: [UIImage] = []
        for file in files {
            guard let data = try? Data(contentsOf: file.url) else { continue }
            if isPDF(name: file.name, data: data) {
                images.append(contentsOf: pageImages(fromPDF: data))
            } else if let image = UIImage(data: data) {
                images.append(image)
            }
        }

        let pipeline = ScanPipeline()
        let draft: ExtractionDraft
        if !images.isEmpty {
            draft = await pipeline.run(images: images)
        } else if !entry.text.isEmpty {
            draft = await pipeline.draft(fromText: entry.text)
        } else {
            return false
        }

        let model = ReviewModel(draft: draft)
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.name = entry.title
        }
        // Provenance: the link it came from, and the text it came with when there was no file.
        model.notes = [entry.url, images.isEmpty ? entry.text : ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        model.save(into: context)
        return true
    }

    private static let pdfMagic = Data("%PDF".utf8)

    private static func isPDF(name: String, data: Data) -> Bool {
        name.lowercased().hasSuffix(".pdf") || data.starts(with: pdfMagic)
    }

    /// Rasterises the first few PDF pages at 2× so Vision has real pixels to read.
    ///
    /// The rendering itself is on the main actor, like Claim Pack's page rendering (C5) — it is one
    /// receipt, not a twenty-page scan — while the OCR and parsing that follow are off it.
    private static func pageImages(fromPDF data: Data, maxPages: Int = 3) -> [UIImage] {
        guard let document = PDFDocument(data: data) else { return [] }
        return (0..<min(document.pageCount, maxPages)).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 1, bounds.height > 1 else { return nil }
            let scale: CGFloat = 2
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: context.cgContext)
            }
        }
    }
}
