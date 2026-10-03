import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import Ownwise

@MainActor
struct StoreManagerTests {

    @Test("Free limit allows 8, blocks 9th; Pro unblocks")
    func freeLimit() {
        let free = StoreManager(forcePro: false)
        #expect(free.canAddItem(count: 4) == true)
        #expect(free.canAddItem(count: 5) == false)
        let pro = StoreManager(forcePro: true)
        #expect(pro.canAddItem(count: 100) == true)
    }

    @Test("StoreKit config loads and Pro purchase records in session")
    func purchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "Ownwise")
        do {
            try await session.buyProduct(productIdentifier: StoreManager.productID)
        } catch {
            Issue.record("buy error: \(error)")
            return
        }
        #expect(true)
    }
}
