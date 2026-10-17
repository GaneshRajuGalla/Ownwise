import Foundation
import PDFKit
import SwiftUI
import UIKit

struct ExportService {
    var locale: Locale = .current
    var now: Date = .now
    var calendar: Calendar = .current

    static let usLetter = CGSize(width: 612, height: 792)
    static let a4 = CGSize(width: 595, height: 842)

    // MARK: CSV

    /// RFC-4180 CSV of all items.
    func makeCSV(items: [Item]) -> Data {
        var rows: [String] = ["name,brand,category,merchant,purchaseDate,price,currencyCode,serialNumber,orderNumber"]
        let iso = ISO8601DateFormatter()
        for it in items {
            rows.append([
                csvField(it.name), csvField(it.brand), csvField(it.category.rawValue),
                csvField(it.merchant), csvField(iso.string(from: it.purchaseDate)),
                it.priceMinor.map { Money.plainString($0, currencyCode: it.currencyCode) } ?? "", csvField(it.currencyCode),
                csvField(it.serialNumber), csvField(it.orderNumber)
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\r\n").data(using: .utf8) ?? Data()
    }

    func csvField(_ s: String) -> String {
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    func csvFile(items: [Item]) throws -> ExportFile {
        try write(makeCSV(items: items), named: "Ownwise Items \(now.formatted(.iso8601.year().month().day())).csv")
    }

    // MARK: Claim Pack

    /// US Letter for US/CA, A4 elsewhere.
    func paperSize() -> CGSize {
        switch locale.region?.identifier {
        case "US", "CA": Self.usLetter
        default: Self.a4
        }
    }

    /// Whole days from today until `end` (negative once past).
    func daysLeft(until end: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
    }

    func coverageLeft(_ c: Coverage) -> String {
        if c.kind == .servicePlan, let next = c.nextServiceDate {
            return String(localized: "Next service \(next.formatted(date: .abbreviated, time: .omitted))")
        }
        let days = daysLeft(until: c.endDate)
        return days < 0 ? String(localized: "Expired") : String(localized: "\(days) days left")
    }

    func claimPackFileName(for item: Item) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:?*|<>\"").union(.newlines)
        let name = item.name.components(separatedBy: unsafe).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return "Claim Pack - \(name.isEmpty ? "Item" : name).pdf"
    }

    /// Images to append after the facts page: receipts and warranty cards first.
    func attachmentImages(of item: Item) -> [(kind: AttachmentKind, image: UIImage)] {
        let order = AttachmentKind.allCases
        return (item.attachments ?? [])
            .compactMap { att -> (AttachmentKind, Date, UIImage)? in
                guard let data = att.fileData else { return nil }
                let kind = AttachmentKind(rawValue: att.kindRaw) ?? .photo
                if let image = UIImage(data: data) { return (kind, att.createdAt, image) }
                if let page = PDFDocument(data: data)?.page(at: 0) {
                    return (kind, att.createdAt, page.thumbnail(of: paperSize(), for: .mediaBox))
                }
                return nil
            }
            .sorted { ($0.0 == $1.0) ? $0.1 < $1.1 : (order.firstIndex(of: $0.0) ?? 0) < (order.firstIndex(of: $1.0) ?? 0) }
            .map { (kind: $0.0, image: $0.2) }
    }

    /// Claim Pack PDF for one item: a vector facts page, then one page per receipt/warranty image.
    /// `watermark` produces the free preview — the same document, marked, so the finished one can
    /// be seen before paying.
    @MainActor
    func makeClaimPackPDF(item: Item, watermark: Bool = false) -> Data {
        let size = paperSize()
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }

        let images = attachmentImages(of: item)
        var pages: [AnyView] = [AnyView(ClaimPackView(item: item, service: self, imageCount: images.count))]
        pages += images.enumerated().map { index, entry in
            AnyView(attachmentPage(item: item, kind: entry.kind, image: entry.image, page: index + 2, of: images.count + 1))
        }

        for page in pages {
            let renderer = ImageRenderer(content: page
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(Color.white)
                .overlay { if watermark { ClaimPackWatermark() } }
                .environment(\.colorScheme, .light))
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return data as Data
    }

    @MainActor
    func claimPackFile(for item: Item, watermark: Bool = false) throws -> ExportFile {
        try write(makeClaimPackPDF(item: item, watermark: watermark), named: claimPackFileName(for: item))
    }

    private func attachmentPage(item: Item, kind: AttachmentKind, image: UIImage, page: Int, of total: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(item.name) · \(kind.label)").font(.headline)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Page \(page) of \(total)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(40)
    }

    // MARK: Files

    func write(_ data: Data, named name: String) throws -> ExportFile {
        guard !data.isEmpty else { throw CocoaError(.fileWriteUnknown) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return ExportFile(url: url)
    }
}
