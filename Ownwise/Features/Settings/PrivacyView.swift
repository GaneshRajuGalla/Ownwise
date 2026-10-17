import SwiftUI

struct PrivacyView: View {
    var body: some View {
        Form {
            Section("Your data stays yours") {
                Label("No account, no analytics, no tracking.", systemImage: "lock.fill")
                Label("Receipt scanning happens 100% on-device.", systemImage: "iphone")
                Label("Nothing is collected or shared with us.", systemImage: "hand.raised.fill")
            }
            Section {
                Label("Your items and receipts live in this app's storage on this iPhone. If you turn on iCloud sync, they are stored in your own private iCloud database — we still cannot see them.", systemImage: "icloud")
            } header: {
                Text("Where your data is")
            }
            Section(header: Text("Policy")) {
                if let privacy = Links.privacyPolicy {
                    Link("Privacy policy", destination: privacy)
                }
                if let support = Links.supportEmail {
                    Link("Contact support", destination: support)
                        .accessibilityIdentifier(AXID.settingsContactLink)
                }
            }
        }
        .navigationTitle("Privacy")
    }
}
