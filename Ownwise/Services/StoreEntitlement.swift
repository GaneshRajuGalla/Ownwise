import Foundation
import StoreKit

/// Whether this device owns Pro, for code that has no `StoreManager`.
///
/// App Intents (E3) run without a scene, so there is no store object to ask, and building one just to
/// answer "may I add this item?" would start StoreKit for a yes/no. The rule is the store's own rule,
/// deliberately kept to one line: a *verified*, non-revoked transaction for the Pro product. Refunds
/// drop out of `currentEntitlements` by themselves, so a refunded purchase is not Pro here either.
enum StoreEntitlement {

    static func isPro() async -> Bool {
        // The same overrides the store honours, so a test sees what it asked for.
        if LaunchEnvironment.forcePro { return true }
        if LaunchEnvironment.forceFree { return false }

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == StoreManager.productID, transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
