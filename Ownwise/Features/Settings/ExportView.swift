import SwiftUI
import SwiftData

struct ExportView: View {
    @Query(sort: \Item.name) private var items: [Item]
    @Environment(StoreManager.self) private var store
    @State private var shareFile: ExportFile?
    @State private var showPaywall = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button { export { try ExportService().csvFile(items: items) } } label: {
                    Label("Export all items (CSV)", systemImage: "tablecells")
                }
                .disabled(items.isEmpty)
                .accessibilityIdentifier(AXID.exportCSVButton)
            } header: {
                Text("Spreadsheet")
            } footer: {
                Text("One row per item with brand, store, purchase date, price, serial and order number. Opens in Numbers, Excel or Google Sheets.")
            }

            Section {
                if items.isEmpty {
                    EmptyStateView(title: "No items yet",
                                   message: "Add an item to create its Claim Pack.",
                                   systemImage: "doc.richtext")
                } else {
                    ForEach(items) { item in
                        Button { export { try ExportService().claimPackFile(for: item) } } label: {
                            Label(item.name, systemImage: "doc.richtext")
                        }
                        .accessibilityIdentifier(AXID.exportClaimPackButton)
                    }
                }
            } header: {
                Text("Claim Pack (PDF)")
            } footer: {
                if !items.isEmpty {
                    Text("Everything a store or manufacturer asks for in a warranty claim: purchase details, serial number, coverage left, and your receipt and warranty card images.")
                }
            }
        }
        .navigationTitle("Export")
        .sheet(item: $shareFile) { file in
            ShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func export(_ make: () throws -> ExportFile) {
        guard store.isPro else { showPaywall = true; return }
        do { shareFile = try make() } catch { errorMessage = error.localizedDescription }
    }
}
