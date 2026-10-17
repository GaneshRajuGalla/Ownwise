import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData
import AVFoundation
import VisionKit

struct ScanFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(StoreManager.self) private var store
    @Query private var items: [Item]
    @State private var showPaywall = false
    @State private var isProcessing = false
    @State private var draft: ExtractionDraft?
    @State private var problem: ScanProblem?
    @State private var photosItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var showPhotos = false
    @State private var showCamera = false

    /// The three ways a scan can stop before Review should be explained, not shrugged at.
    enum ScanProblem: Identifiable {
        case cameraDenied
        case cameraUnavailable
        case unreadableReceipt

        var id: String {
            switch self {
            case .cameraDenied: "cameraDenied"
            case .cameraUnavailable: "cameraUnavailable"
            case .unreadableReceipt: "unreadableReceipt"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .cameraDenied: "Camera access is off"
            case .cameraUnavailable: "Scanning isn't available here"
            case .unreadableReceipt: "We couldn't read that"
            }
        }

        var message: LocalizedStringKey {
            switch self {
            case .cameraDenied:
                "Ownwise needs the camera to scan a receipt. You can turn it on in Settings, or pick a photo you already have."
            case .cameraUnavailable:
                "This device can't use the document scanner. Pick a photo of the receipt, or type the details in."
            case .unreadableReceipt:
                "No text came off that image. Try a sharper photo in good light, or type the details in."
            }
        }

        var systemImage: String {
            switch self {
            case .cameraDenied: "camera.badge.ellipsis"
            case .cameraUnavailable: "camera.metering.unknown"
            case .unreadableReceipt: "doc.questionmark"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let problem {
                    problemView(problem)
                } else if draft == nil && !store.canAddItem(count: items.count) {
                    EmptyStateView(title: "Free limit reached",
                                   message: "The free version keeps up to \(StoreManager.freeItemLimit) items. Unlock Pro to add unlimited items.",
                                   systemImage: "lock",
                                   actionTitle: "Unlock Pro") { showPaywall = true }
                } else if let draft {
                    ReviewView(model: ReviewModel(draft: draft)) { dismiss() }
                } else if isProcessing {
                    ContentUnavailableView("Reading receipt…", systemImage: "doc.text.magnifyingglass")
                        .overlay(alignment: .bottom) { ProgressView().padding(.bottom, 80) }
                } else if showCamera {
                    DocumentCamera { imgs in showCamera = false; start(images: imgs) } onFail: { cameraFailed() }
                        .ignoresSafeArea()
                } else {
                    picker
                }
            }
            .navigationTitle(showCamera ? "" : "Scan")
            .toolbar(showCamera ? .hidden : .visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() }.accessibilityIdentifier(AXID.cancelButton) } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func problemView(_ problem: ScanProblem) -> some View {
        let actions = problemActions(problem)
        return ContentUnavailableView {
            Label(problem.title, systemImage: problem.systemImage)
        } description: {
            Text(problem.message)
        } actions: {
            Button(actions.primaryTitle) { actions.primary() }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier(AXID.scanProblemPrimary)
            Button(actions.secondaryTitle) { actions.secondary() }
                .accessibilityIdentifier(AXID.scanProblemSecondary)
        }
        .accessibilityIdentifier(AXID.scanProblem)
    }

    private struct ProblemActions {
        var primaryTitle: LocalizedStringKey
        var primary: () -> Void
        var secondaryTitle: LocalizedStringKey
        var secondary: () -> Void
    }

    /// Every dead end offers a way forward: Settings, a photo, or typing it in.
    private func problemActions(_ problem: ScanProblem) -> ProblemActions {
        switch problem {
        case .cameraDenied:
            ProblemActions(primaryTitle: "Open Settings",
                           primary: openAppSettings,
                           secondaryTitle: "Choose a photo",
                           secondary: { clearProblem(); showPhotos = true })
        case .cameraUnavailable:
            ProblemActions(primaryTitle: "Choose a photo",
                           primary: { clearProblem(); showPhotos = true },
                           secondaryTitle: "Enter it manually",
                           secondary: { clearProblem(); draft = ExtractionDraft() })
        case .unreadableReceipt:
            ProblemActions(primaryTitle: "Try another photo",
                           primary: { clearProblem(); showPhotos = true },
                           secondaryTitle: "Enter it manually",
                           secondary: { clearProblem(); draft = ExtractionDraft() })
        }
    }

    var picker: some View {
        List {
            Button { startFromCamera() } label: { Label("Camera", systemImage: "camera") }
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
            guard case .success(let url) = result else { return }
            readFile(at: url)
        }
    }

    // MARK: Entry points

    private func startFromCamera() {
        #if DEBUG
        // UI-test paths: no camera in the simulator, and a forced failure state so the C4
        // screens can be exercised on any device.
        if LaunchEnvironment.fixtureReceipt != nil { start(images: []); return }
        if LaunchEnvironment.forceScanUnavailable { problem = .cameraUnavailable; return }
        if LaunchEnvironment.forceScanUnreadable { start(images: []); return }
        #endif
        guard VNDocumentCameraViewController.isSupported else {
            problem = .cameraUnavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            problem = .cameraDenied
        default:
            // `.notDetermined` is fine: the scanner asks, and `cameraFailed` handles a refusal.
            showCamera = true
        }
    }

    /// Cancel and failure both arrive here. Only a refused permission deserves an explanation;
    /// the user's own cancel must stay silent.
    private func cameraFailed() {
        showCamera = false
        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            problem = .cameraDenied
        }
    }

    private func readFile(at url: URL) {
        let needsRelease = url.startAccessingSecurityScopedResource()
        defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
        if let pdf = PDFDocument(url: url) {
            var imgs: [UIImage] = []
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) { imgs.append(page.thumbnail(of: CGSize(width: 1500, height: 2000), for: .mediaBox)) }
            }
            guard !imgs.isEmpty else { problem = .unreadableReceipt; return }
            start(images: imgs)
        } else if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            start(images: [img])
        } else {
            problem = .unreadableReceipt
        }
    }

    private func clearProblem() { problem = nil }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    func start(images: [UIImage]) {
        isProcessing = true
        Task {
            #if DEBUG
            if LaunchEnvironment.forceScanUnreadable {
                isProcessing = false
                problem = .unreadableReceipt
                return
            }
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
            #endif
            let result = await ScanPipeline().run(images: images)
            isProcessing = false
            if result.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problem = .unreadableReceipt
            } else {
                draft = result
            }
        }
    }
}

#if DEBUG
/// Fixture OCR text for UI tests and previews. Debug only, so no fixture text ships in the
/// App Store build.
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
#endif
