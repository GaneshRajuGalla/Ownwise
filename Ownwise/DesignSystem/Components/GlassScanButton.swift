import SwiftUI

struct GlassScanButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Scan a receipt", systemImage: "doc.viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .accessibilityIdentifier(AXID.scanButton)
        .accessibilityHint("Opens the camera to scan a receipt or warranty card")
    }
}
