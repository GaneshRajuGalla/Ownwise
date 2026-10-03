import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        header
                        features
                        if let product = store.product {
                            ProductView(id: product.id)
                                .frame(minHeight: 80)
                        } else {
                            Text("One-time purchase · $4.99").font(.title2.bold())
                        }
                        Button("Restore purchases") { Task { await store.restore() } }
                            .font(.footnote)
                            .accessibilityIdentifier(AXID.paywallRestoreButton)
                        legalLinks
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DS.Space.l)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier(AXID.paywallDismiss) } }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Image(systemName: "crown.fill").font(.system(size: 48)).foregroundStyle(.indigo)
            Text("Unlock Ownwise Pro").font(.largeTitle.bold())
            Text("One purchase. No subscription. Keep track of everything you own.").foregroundStyle(.secondary)
        }
    }

    var features: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            benefit("Unlimited items")
            benefit("Service plans & maintenance")
            benefit("Claim Pack PDF export")
            benefit("CSV export")
            benefit("App lock")
        }
        .padding(.top, DS.Space.s)
    }

    var legalLinks: some View {
        HStack {
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/uk/terms.html")!)
            Link("Privacy", destination: URL(string: "mailto:ganeshraju14014@gmail.com")!)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    func benefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary)
            .imageScale(.large)
            .tint(.indigo)
    }
}
