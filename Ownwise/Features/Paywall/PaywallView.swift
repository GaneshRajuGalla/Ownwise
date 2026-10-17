import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store
    @Environment(\.purchase) private var purchase
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.xxl) {
                    header
                    features
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.bottom, DS.Space.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier(AXID.paywallDismiss)
                }
            }
            .alert("Ownwise Pro", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
            .task { await store.loadProduct() }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: Sections

    var header: some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "crown.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Color.indigo.gradient, in: .rect(cornerRadius: DS.Radius.card, style: .continuous))
                .accessibilityHidden(true)
            Text("Ownwise Pro")
                .font(.largeTitle.bold())
            Text("Pay once. Keep every receipt, warranty and claim in one place, for good.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Space.l)
    }

    var features: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {
            feature("infinity", "Unlimited items", "Go beyond the \(StoreManager.freeItemLimit)-item free limit.")
            feature("doc.richtext", "Claim Pack PDF", "Receipt, serial and coverage in one file for any warranty claim.")
            feature("tablecells", "CSV export", "Your whole inventory as a spreadsheet.")
            feature("bell.badge", "Custom reminder timing", "Any lead time you like, your own reminder hour, and one-off reminders on any date.")
            feature("wrench.and.screwdriver", "Service plans", "Reminders for maintenance and servicing.")
        }
    }

    var purchaseBar: some View {
        VStack(spacing: DS.Space.m) {
            if store.isPro {
                Label("You own Ownwise Pro", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button { Task { await buy() } } label: {
                    ZStack {
                        Text(purchaseTitle).font(.headline).opacity(isWorking ? 0 : 1)
                        if isWorking { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.xs)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(isWorking)
                .accessibilityIdentifier(AXID.paywallPurchaseButton)

                Text("One-time payment. No subscription.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DS.Space.m) {
                Button("Restore purchases") { Task { await restore() } }
                    .accessibilityIdentifier(AXID.paywallRestoreButton)
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Link("Privacy policy", destination: URL(string: "https://ganeshrajugalla.github.io/Ownwise/privacy.html")!)
            }
            .font(.footnote)
            .disabled(isWorking)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.l)
        .padding(.bottom, DS.Space.s)
        .frame(maxWidth: .infinity)
        .background {
            Color(.systemBackground)
                .overlay(alignment: .top) { Divider() }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    var purchaseTitle: String {
        if let price = store.product?.displayPrice { String(localized: "Unlock Pro · \(price)") }
        else { String(localized: "Unlock Pro") }
    }

    func feature(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.15), in: .rect(cornerRadius: DS.Radius.chip, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    func buy() async {
        isWorking = true
        defer { isWorking = false }
        await store.loadProduct()
        guard let product = store.product else {
            message = String(localized: "The App Store isn't available right now. Please try again later.")
            return
        }
        do {
            switch await store.handle(try await purchase(product)) {
            case .purchased, .cancelled:
                break
            case .pending:
                message = String(localized: "Your purchase is waiting for approval. Pro unlocks automatically once it's approved.")
            case .failedVerification:
                message = String(localized: "The App Store couldn't verify this purchase, so Pro wasn't unlocked. Please try again.")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.restore()
            if !store.isPro {
                message = String(localized: "No previous Ownwise Pro purchase was found for this Apple Account.")
            }
        } catch StoreKitError.userCancelled {
            // User dismissed the App Store sign-in; nothing to report.
        } catch {
            message = error.localizedDescription
        }
    }
}
