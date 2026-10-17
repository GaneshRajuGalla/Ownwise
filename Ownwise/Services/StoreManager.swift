import Foundation
import StoreKit
import Observation
import os

/// StoreKit 2 store for the single non-consumable "Ownwise Pro".
/// Follows Apple's "Implementing a store in your app using the StoreKit API":
/// listen to `Transaction.updates` from launch, process `Transaction.unfinished`,
/// grant access only from verified `currentEntitlements` (refunds drop out automatically),
/// finish transactions after delivering, and call `AppStore.sync()` only on user request.
@Observable
@MainActor
final class StoreManager {
    static let productID = "com.ownwise.Ownwise.pro"

    /// Free is a real library, not a demo: a dozen-plus items before the limit appears.
    /// Pro is carried by the Claim Pack PDF, custom reminder timing and iCloud sync.
    static let freeItemLimit = 15
    private static let log = Logger(subsystem: "com.ownwise.Ownwise", category: "StoreKit")

    enum PurchaseOutcome: Equatable, Sendable {
        case purchased, pending, cancelled, failedVerification
    }

    private(set) var isPro = false
    private(set) var product: Product?
    private var forcePro: Bool?
    private var updatesTask: Task<Void, Never>?

    init(forcePro: Bool? = nil) {
        self.forcePro = forcePro
        if let forcePro { isPro = forcePro }
        // Start as early as possible so purchases made elsewhere (Ask to Buy approvals,
        // other devices, refunds, offer-code redemptions) are never missed.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.process(result)
            }
        }
    }

    isolated deinit { updatesTask?.cancel() }

    /// Call once at launch: deliver anything left unfinished, rebuild entitlements, load the product.
    func start() async {
        Self.trace(.default, "StoreKit start: requesting \(Self.productID)")
        // Load the product independently so a slow entitlement check never delays the price.
        async let productLoad: Void = loadProduct()
        for await result in Transaction.unfinished {
            await process(result)
        }
        await refreshEntitlements()
        await productLoad
    }

    /// Fetches the Pro product if it isn't loaded yet (e.g. first launch was offline).
    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            if let product {
                Self.trace(.default, """
                Loaded product \(product.id): name=\(product.displayName) \
                price=\(product.displayPrice) (\(product.price.description)) \
                currency=\(product.priceFormatStyle.currencyCode) type=\(product.type.rawValue) \
                familyShareable=\(product.isFamilyShareable)
                """)
            } else {
                Self.trace(.error, "No product returned for \(Self.productID). Check the StoreKit config or App Store Connect setup.")
            }
        } catch {
            Self.trace(.error, "Product request failed: \(error.localizedDescription)")
        }
    }

    /// Pro = a verified, non-revoked entitlement. Refunded / revoked purchases don't appear here.
    func refreshEntitlements() async {
        if forcePro != nil { return }
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == Self.productID, tx.revocationDate == nil {
                pro = true
                Self.trace(.default, "Entitlement: id=\(tx.id) purchased=\(tx.purchaseDate.formatted()) environment=\(tx.environment.rawValue)")
            }
        }
        isPro = pro
        Self.trace(.default, "Entitlements refreshed: isPro=\(pro)")
    }

    /// Applies the result of SwiftUI's `PurchaseAction`. Never grants access for unverified transactions.
    @discardableResult
    func handle(_ result: Product.PurchaseResult) async -> PurchaseOutcome {
        switch result {
        case .success(.verified(let tx)):
            Self.trace(.default, "Purchase verified: id=\(tx.id) product=\(tx.productID) environment=\(tx.environment.rawValue) storefront=\(tx.storefront.countryCode)")
            await tx.finish()
            await refreshEntitlements()
            return .purchased
        case .success(.unverified(_, let error)):
            Self.trace(.error, "Purchase failed verification: \(error.localizedDescription)")
            return .failedVerification
        case .pending:
            // Ask to Buy / SCA: the approved transaction arrives later through `Transaction.updates`.
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Only in response to the Restore button: `AppStore.sync()` shows an App Store sign-in prompt.
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func canAddItem(count: Int) -> Bool {
        isPro || count < Self.freeItemLimit
    }

    /// Logs to the unified log (Console.app, category "StoreKit") and, in debug builds,
    /// prints so it always shows in Xcode's console on device too.
    private static func trace(_ type: OSLogType, _ message: String) {
        log.log(level: type, "\(message, privacy: .public)")
        #if DEBUG
        print("[StoreKit] \(message)")
        #endif
    }

    private func process(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        await refreshEntitlements()
        await tx.finish()
    }
}
