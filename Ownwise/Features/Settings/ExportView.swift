import SwiftUI
import SwiftData

struct ExportView: View {
    @Query private var items: [Item]
    @Environment(StoreManager.self) private var store
    @State private var csvURL: URL?
    @State private var pdfURL: URL?

    var body: some View {
        List {
            Section("All items") {
                Button("Export CSV") { exportCSV() }
                    .accessibilityIdentifier(AXID.exportCSVButton)
                if !store.isPro { Text("Pro required for CSV export").font(.footnote).foregroundStyle(.secondary) }
            }
            Section("Claim Pack (PDF)") {
                ForEach(items) { item in
                    Button(item.name) { exportPDF(item) }
                        .accessibilityIdentifier(AXID.exportClaimPackButton)
                }
            }
            if let csvURL {
                ShareLink(item: csvURL) { Text("Share CSV") }
            }
            if let pdfURL {
                ShareLink(item: pdfURL) { Text("Share PDF") }
            }
        }
        .navigationTitle("Export")
    }

    func exportCSV() {
        let data = ExportService().makeCSV(items: items)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ownwise-items.csv")
        try? data.write(to: url)
        csvURL = url
    }

    func exportPDF(_ item: Item) {
        let data = ExportService().makeClaimPackPDF(item: item)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("claim-pack-\(item.id.uuidString).pdf")
        try? data.write(to: url)
        pdfURL = url
    }
}
