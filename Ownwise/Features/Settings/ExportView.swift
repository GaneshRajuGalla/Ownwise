import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Query(sort: \Item.name) private var items: [Item]
    @Environment(StoreManager.self) private var store
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(\.modelContext) private var modelContext

    @State private var shareFile: ExportFile?
    @State private var showPaywall = false
    @State private var showRestorePicker = false
    @State private var pendingRestore: BackupService.Backup?
    @State private var notice: Notice?

    /// One alert for every outcome, so two `alert` modifiers never compete for the same view.
    private struct Notice {
        var title: String
        var message: String
    }

    var body: some View {
        List {
            backupSection
            spreadsheetSection
            claimPackSection
        }
        .navigationTitle("Export")
        .sheet(item: $shareFile) { file in
            ShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .fileImporter(isPresented: $showRestorePicker, allowedContentTypes: [.json]) { result in
            readBackup(from: result)
        }
        .confirmationDialog(
            "Replace everything with this backup?",
            isPresented: restoreDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Replace my library", role: .destructive) { confirmRestore() }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Your current items, receipts and photos are removed first. This cannot be undone.")
        }
        .alert(
            notice?.title ?? "",
            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice?.message ?? "")
        }
    }

    // MARK: Sections

    private var backupSection: some View {
        Section {
            Button { export { try BackupService().file(items: items) } } label: {
                Label("Save a backup file", systemImage: "arrow.up.doc")
            }
            .disabled(items.isEmpty)
            .accessibilityIdentifier(AXID.exportBackupButton)

            Button { showRestorePicker = true } label: {
                Label("Restore from a backup", systemImage: "arrow.down.doc")
            }
            .accessibilityIdentifier(AXID.exportRestoreButton)
        } header: {
            Text("Backup")
        } footer: {
            Text("A backup holds every item, coverage, receipt and photo, so you can move to a new phone or undo a mistake. Free, always — your data is yours.")
        }
    }

    private var spreadsheetSection: some View {
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
    }

    private var claimPackSection: some View {
        Section {
            if !store.isPro {
                Button { showPaywall = true } label: {
                    Label("See what Pro adds", systemImage: "crown")
                }
                .accessibilityIdentifier(AXID.exportProButton)
            }
            if items.isEmpty {
                EmptyStateView(title: "No items yet",
                               message: "Add an item to create its Claim Pack.",
                               systemImage: "doc.richtext")
            } else {
                ForEach(items) { item in
                    Button { exportClaimPack(for: item) } label: {
                        HStack {
                            Label(item.name, systemImage: "doc.richtext")
                            Spacer(minLength: DS.Space.s)
                            if !store.isPro { ProBadge() }
                        }
                    }
                    .accessibilityIdentifier(AXID.exportClaimPackButton)
                }
            }
        } header: {
            Text("Claim Pack (PDF)")
        } footer: {
            if !items.isEmpty {
                if store.isPro {
                    Text("Everything a store or manufacturer asks for in a warranty claim: purchase details, serial number, coverage left, and your receipt and warranty card images.")
                } else {
                    Text("Tapping an item makes a watermarked preview you can share or print. Pro removes the mark.")
                }
            }
        }
    }

    // MARK: Actions

    /// Raw export and backups are free; the Claim Pack is watermarked for free users rather than
    /// blocked, so the value is visible before paying.
    private func export(_ make: () throws -> ExportFile) {
        do {
            shareFile = try make()
        } catch {
            notice = Notice(title: String(localized: "Export failed"), message: error.localizedDescription)
        }
    }

    private func exportClaimPack(for item: Item) {
        export { try ExportService().claimPackFile(for: item, watermark: !store.isPro) }
    }

    private var restoreDialogPresented: Binding<Bool> {
        Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })
    }

    private func readBackup(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let needsRelease = url.startAccessingSecurityScopedResource()
            defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingRestore = try BackupService().decode(data)
        } catch {
            notice = Notice(title: String(localized: "Couldn't read that backup"),
                            message: error.localizedDescription)
        }
    }

    private func confirmRestore() {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        do {
            try BackupService().restore(backup, into: modelContext)
            Task { await reminder.rescheduleFromContext(modelContext) }
            notice = Notice(
                title: String(localized: "Backup restored"),
                message: backup.items.count == 1
                    ? String(localized: "1 item is back in Ownwise.")
                    : String(localized: "\(backup.items.count) items are back in Ownwise.")
            )
        } catch {
            notice = Notice(title: String(localized: "Couldn't restore that backup"),
                            message: error.localizedDescription)
        }
    }
}
