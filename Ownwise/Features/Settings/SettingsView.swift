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
    @State private var showReminders = false
    @State private var remindersAfterPurchase = false
    @State private var showSyncNotice = false

    /// The horizon behind every "expiring soon" badge (E7). Written here; read by
    /// `LibraryPreferences.soonDays` wherever the question is asked.
    @AppStorage(LibraryPreferences.key) private var soonDays = LibraryPreferences.defaultSoonDays

    var body: some View {
        NavigationStack {
            List {
                Section("Pro") {
                    HStack { Text("Status"); Spacer(); Text(store.isPro ? "Pro" : "Free").foregroundStyle(.secondary) }
                    Button(store.isPro ? "Manage Pro" : "Upgrade to Pro") { showPaywall = true }
                        .accessibilityIdentifier(AXID.settingsUpgradeButton)
                }
                Section {
                    Button { openReminders() } label: { proRow("Customize reminders") }
                        .accessibilityIdentifier(AXID.settingsRemindersButton)
                    Picker("Expiring soon means", selection: $soonDays) {
                        ForEach(LibraryPreferences.soonDayOptions, id: \.self) { days in
                            Text(LibraryPreferences.label(for: days)).tag(days)
                        }
                    }
                    .accessibilityIdentifier(AXID.settingsSoonDaysPicker)
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
                        .accessibilityIdentifier(AXID.settingsAppLockToggle)
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
                    Button("Export & backup") { showExport = true }
                        .accessibilityIdentifier(AXID.settingsExportButton)
                    NavigationLink("Privacy") { PrivacyView() }
                        .accessibilityIdentifier(AXID.settingsPrivacyLink)
                }
                if SyncSettings.isAvailable {
                    Section {
                        Toggle("Sync with iCloud", isOn: Binding(get: { SyncSettings.isEnabled },
                                                                  set: { on in
                                                                      SyncSettings.isEnabled = on
                                                                      showSyncNotice = true
                                                                  }))
                            .accessibilityIdentifier(AXID.settingsSyncToggle)
                    } header: {
                        Text("iCloud")
                    } footer: {
                        Text("Your own private iCloud database — never our servers. Reopen Ownwise to apply. Receipts and photos count toward your iCloud storage.")
                    }
                }
                if Persistence.didRecoverStore {
                    Section {
                        Label("Ownwise couldn't open your saved data, so it started an empty library.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Data recovery")
                    } footer: {
                        Text("The old file was kept, not deleted. Use Export & backup to restore your items.")
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    if let support = Links.supportEmail {
                        Link("Contact support", destination: support)
                            .accessibilityIdentifier(AXID.settingsContactLink)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showExport) { ExportView() }
            .navigationDestination(isPresented: $showReminders) { ReminderSettingsView() }
            .sheet(isPresented: $showPaywall, onDismiss: {
                if store.isPro {
                    if remindersAfterPurchase { showReminders = true }
                }
                remindersAfterPurchase = false
            }) { PaywallView() }
            .alert("Sync setting saved", isPresented: $showSyncNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Close and reopen Ownwise to apply this change.")
            }
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
}
