import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import Ownwise

@MainActor
@Suite(.serialized)
struct StoreManagerTests {

    @Test("Free limit blocks the item after the limit; Pro unblocks")
    func freeLimit() {
        let free = StoreManager(forcePro: false)
        #expect(free.canAddItem(count: 4) == true)
        #expect(free.canAddItem(count: 5) == false)
        let pro = StoreManager(forcePro: true)
        #expect(pro.canAddItem(count: 100) == true)
    }

    @Test("Service plans need Pro; other coverage kinds are free")
    func coverageGate() {
        let free = StoreManager(forcePro: false)
        #expect(free.canAddCoverage(.servicePlan) == false)
        for kind in CoverageKind.allCases where kind != .servicePlan {
            #expect(free.canAddCoverage(kind) == true)
        }
        #expect(StoreManager(forcePro: true).canAddCoverage(.servicePlan) == true)
    }

    @Test("loadProduct fetches the Pro product from the StoreKit config")
    func loadProduct() async throws {
        let session = try SKTestSession(configurationFileNamed: "Ownwise")
        session.disableDialogs = true
        let store = StoreManager(forcePro: false)
        await store.loadProduct()
        #expect(store.product?.id == StoreManager.productID)
        #expect(store.product?.price == Decimal(string: "4.99"))
    }

    @Test("StoreKit config loads and Pro purchase records in session")
    func purchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "Ownwise")
        do {
            let transaction = try await session.buyProduct(identifier: StoreManager.productID)
            #expect(transaction.productID == StoreManager.productID)
        } catch {
            Issue.record("buy error: \(error)")
        }
    }

    @Test("Verified purchase unlocks Pro; refund revokes it")
    func purchaseThenRefund() async throws {
        let session = try SKTestSession(configurationFileNamed: "Ownwise")
        session.disableDialogs = true
        session.clearTransactions()
        let store = StoreManager()

        await store.refreshEntitlements()
        #expect(store.isPro == false)

        let transaction = try await session.buyProduct(identifier: StoreManager.productID)
        await store.refreshEntitlements()
        #expect(store.isPro == true)

        try session.refundTransaction(identifier: UInt(transaction.id))
        // The refund reaches StoreKit asynchronously (the app picks it up via Transaction.updates).
        for _ in 0..<20 where store.isPro {
            try await Task.sleep(for: .milliseconds(250))
            await store.refreshEntitlements()
        }
        #expect(store.isPro == false)
        session.clearTransactions()
    }

    @Test("Pending and cancelled purchases never unlock Pro")
    func nonSuccessOutcomes() async {
        let store = StoreManager(forcePro: false)
        #expect(await store.handle(.pending) == .pending)
        #expect(await store.handle(.userCancelled) == .cancelled)
        #expect(store.isPro == false)
    }
}
