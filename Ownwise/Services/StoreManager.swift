import Foundation
import StoreKit
import Observation

@Observable
@MainActor
final class StoreManager {
    static let productID = "com.ownwise.Ownwise.pro"
    static let freeItemLimit = 5

    private(set) var isPro = false
    private(set) var product: Product?
    private var forcePro: Bool?

    init(forcePro: Bool? = nil) {
        self.forcePro = forcePro
        if let forcePro { isPro = forcePro }
    }

    func startListening() async {
        // Listen for transaction updates for the life of the app.
        Task { @MainActor [weak self] in
            for await update in Transaction.updates {
                if case .verified(let tx) = update {
                    if tx.productID == Self.productID { await tx.finish() }
                    await self?.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refreshEntitlements() async {
        if forcePro != nil { return }
        var pro = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let tx) = entitlement, tx.productID == Self.productID { pro = true }
        }
        isPro = pro
    }

    func purchase() async throws {
        guard let product else { return }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let tx) = verification { await tx.finish() }
            await refreshEntitlements()
        default: break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func canAddItem(count: Int) -> Bool {
        isPro || count < Self.freeItemLimit
    }
}
