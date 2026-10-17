import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppLock.self) private var appLock
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(\.openURL) private var openURL

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
                    Button { openReminders() } label: { proRow("Customize reminders") }
                        .accessibilityIdentifier(AXID.settingsRemindersButton)
                    if notificationsDenied {
                        Button { openNotificationSettings() } label: {
                            Label("Turn on notifications", systemImage: "bell.badge")
                        }
                        .accessibilityIdentifier(AXID.settingsNotificationsButton)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(notificationsDenied
                         ? "Notifications are off, so reminders can't reach you."
                         : reminder.preferences.summary)
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
                    Button { openExport() } label: { proRow("Export") }
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

    /// Rows that lead a free user straight to the paywall are badged, so the
    /// upgrade is never a surprise. Pro users see a plain row.
    private func proRow(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: DS.Space.s)
            if !store.isPro { ProBadge() }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// The system permission, not our preference: without it no reminder can arrive, so the
    /// screen says so and offers the one route back (the app's page in the Settings app).
    private var notificationsDenied: Bool { !reminder.authorizationGranted }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
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
