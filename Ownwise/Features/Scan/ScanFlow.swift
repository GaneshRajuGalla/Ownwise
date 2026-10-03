import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

struct ScanFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var images: [UIImage] = []
    @State private var isProcessing = false
    @State private var draft: ExtractionDraft?
    @State private var photosItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var showPhotos = false

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    ReviewView(model: ReviewModel(draft: draft)) { dismiss() }
                } else if isProcessing {
                    ContentUnavailableView("Reading receipt…", systemImage: "doc.text.magnifyingglass")
                        .overlay(alignment: .bottom) { ProgressView().padding(.bottom, 80) }
                } else if showCamera {
                    DocumentCamera { imgs in showCamera = false; start(images: imgs) } onFail: { showCamera = false }
                        .ignoresSafeArea()
                } else {
                    picker
                }
            }
            .navigationTitle(showCamera ? "" : "Scan")
            .toolbar(showCamera ? .hidden : .visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() }.accessibilityIdentifier(AXID.cancelButton) } }
        }
    }

    @State private var showCamera = false

    var picker: some View {
        List {
            Button { if LaunchEnvironment.fixtureReceipt != nil { start(images: []) } else { showCamera = true } } label: { Label("Camera", systemImage: "camera") }
                .accessibilityIdentifier(AXID.cameraButton)
            Button { showPhotos = true } label: { Label("Photos", systemImage: "photo") }
                .accessibilityIdentifier(AXID.photosButton)
            Button { showFiles = true } label: { Label("Files (PDF)", systemImage: "folder") }
                .accessibilityIdentifier(AXID.filesButton)
            Button {
                draft = ExtractionDraft()
            } label: { Label("Manual entry", systemImage: "square.and.pencil") }
                .accessibilityIdentifier(AXID.manualEntryButton)
        }
        .photosPicker(isPresented: $showPhotos, selection: $photosItem, matching: .images)
        .onChange(of: photosItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) { start(images: [img]) }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let pdf = PDFDocument(url: url) {
                    var imgs: [UIImage] = []
                    for i in 0..<pdf.pageCount {
                        if let page = pdf.page(at: i) { imgs.append(page.thumbnail(of: CGSize(width: 1500, height: 2000), for: .mediaBox)) }
                    }
                    start(images: imgs)
                } else if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    start(images: [img])
                }
            }
        }
    }

    func start(images: [UIImage]) {
        self.images = images
        isProcessing = true
        Task {
            // UI-test fixture path: skip Vision/AI, use canned OCR text.
            if let fixture = LaunchEnvironment.fixtureReceipt {
                let parsed = ReceiptParser().parse(Fixtures.receipt(named: fixture))
                var d = ExtractionDraft(
                    merchant: parsed.merchant ?? "",
                    serialNumber: parsed.serialNumber ?? "",
                    purchaseDate: parsed.purchaseDate,
                    totalMinor: parsed.totalMinor,
                    currencyCode: parsed.currencyCode ?? "",
                    warrantyMonths: parsed.warrantyMonths,
                    returnDays: parsed.returnDays,
                    orderNumber: parsed.orderNumber ?? "",
                    ocrText: Fixtures.receipt(named: fixture)
                )
                d.name = parsed.productName ?? ""
                isProcessing = false
                draft = d
                return
            }
            let cgs = images.compactMap(\.cgImage)
            let d = await ScanPipeline().run(images: cgs)
            isProcessing = false
            draft = d
        }
    }
}

/// Fixture OCR text used by UI tests and the `-fixtureReceipt` launch arg.
enum Fixtures {
    static func receipt(named name: String) -> String {
        switch name {
        case "us":
            return """
            Best Buy
            Order #BBY01-2345678
            OLED TV 55 inch LG
            Date: 09/15/2026
            Grand Total: $1,299.50
            1 Year Limited Warranty
            30-day return policy
            S/N: C02ABCDE123
            """
        case "eu":
            return """
            MediaMarkt
            Rechnung Nr. DE-12345
            Datum: 15.09.2026
            Gesamt: 1.299,50 €
            2 Jahre Garantie
            14 Tage Rückgaberecht
            """
        default:
            return "Unknown merchant\nTotal: $10.00"
        }
    }
}
