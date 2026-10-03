import SwiftUI

struct PrivacyView: View {
    var body: some View {
        Form {
            Section("Your data stays on your iPhone") {
                Label("No account, no cloud, no analytics.", systemImage: "lock.fill")
                Label("Receipt scanning happens 100% on-device.", systemImage: "iphone")
                Label("Nothing is collected or shared.", systemImage: "hand.raised.fill")
            }
            Section(header: Text("Policy")) {
                Link("Privacy policy", destination: URL(string: "https://ganeshrajugalla.github.io/Ownwise/privacy.html")!)
                Link("Support", destination: URL(string: "https://ganeshrajugalla.github.io/Ownwise/support.html")!)
            }
        }
        .navigationTitle("Privacy")
    }
}
