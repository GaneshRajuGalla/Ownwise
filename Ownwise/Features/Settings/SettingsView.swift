import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppLock.self) private var appLock
    @Query private var items: [Item]

    @State private var showPaywall = false
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            List {
                Section("Pro") {
                    HStack { Text("Status"); Spacer(); Text(store.isPro ? "Pro" : "Free").foregroundStyle(.secondary) }
                    Button(store.isPro ? "Manage Pro" : "Upgrade to Pro") { showPaywall = true }
                    Button("Restore purchases") { Task { await store.restore() } }
                        .accessibilityIdentifier(AXID.paywallRestoreButton)
                }
                Section("Security") {
                    Toggle("App lock (Face ID)", isOn: Binding(get: { appLock.isEnabled }, set: { appLock.isEnabled = $0 }))
                }
                Section("Data") {
                    NavigationLink("Export") { ExportView() }
                    NavigationLink("Privacy") { PrivacyView() }
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Link("Support website", destination: URL(string: "https://ganeshrajugalla.github.io/Ownwise/support.html")!)
                    Link("Contact support", destination: URL(string: "mailto:ganeshraju14014@gmail.com")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}
