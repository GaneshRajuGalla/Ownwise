import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppLock.self) private var appLock
    @Environment(ReminderScheduler.self) private var reminder
    @Query private var items: [Item]

    @State private var showPaywall = false
    @State private var showExport = false
    @State private var exportAfterPurchase = false
    @State private var showReminders = false
    @State private var remindersAfterPurchase = false

    var body: some View {
        NavigationStack {
            List {
                Section("Pro") {
                    HStack { Text("Status"); Spacer(); Text(store.isPro ? "Pro" : "Free").foregroundStyle(.secondary) }
                    Button(store.isPro ? "Manage Pro" : "Upgrade to Pro") { showPaywall = true }
                }
                Section {
                    Button("Customize reminders") { openReminders() }
                        .accessibilityIdentifier(AXID.settingsRemindersButton)
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(reminder.preferences.summary)
                }
                Section {
                    Toggle("App lock (Face ID)", isOn: Binding(get: { appLock.isEnabled },
                                                               set: { on in Task { await appLock.setEnabled(on) } }))
                        .disabled(!appLock.isEnabled && !appLock.canAuthenticate)
                } header: {
                    Text("Security")
                } footer: {
                    if !appLock.isEnabled && !appLock.canAuthenticate {
                        Text("Set up Face ID or a passcode in the Settings app to use app lock.")
                    } else {
                        Text("Locks Ownwise after it's been in the background for a minute.")
                    }
                }
                Section("Data") {
                    Button("Export") { openExport() }
                        .accessibilityIdentifier(AXID.settingsExportButton)
                    NavigationLink("Privacy") { PrivacyView() }
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link("Contact support", destination: URL(string: "mailto:ganeshraju14014@gmail.com")!)
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showExport) { ExportView() }
            .navigationDestination(isPresented: $showReminders) { ReminderSettingsView() }
            .sheet(isPresented: $showPaywall, onDismiss: {
                if store.isPro {
                    if exportAfterPurchase { showExport = true }
                    if remindersAfterPurchase { showReminders = true }
                }
                exportAfterPurchase = false
                remindersAfterPurchase = false
            }) { PaywallView() }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Custom reminders are Pro-only: free users see the paywall, then land on Reminders if they buy.
    private func openReminders() {
        if store.isPro {
            showReminders = true
        } else {
            remindersAfterPurchase = true
            showPaywall = true
        }
    }

    /// Export is Pro-only: free users see the paywall, then land on Export if they buy.
    private func openExport() {
        if store.isPro {
            showExport = true
        } else {
            exportAfterPurchase = true
            showPaywall = true
        }
    }
}
