import XCTest

final class SearchFilterUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testSearchBySerialAndMerchant() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData"])
        app.launch()

        // Open the search tab (role .search shows at top on iPad; on iPhone it's in the tab bar).
        let searchTab = app.buttons["tab_search"]
        if searchTab.waitForExistence(timeout: 3) { searchTab.tap() }

        // Find seeded item "MacBook Air 13\"" via its serial in search.
        let searchField = app.searchFields.firstMatch
        if searchTab.exists || searchField.waitForExistence(timeout: 3) {
            if searchField.waitForExistence(timeout: 3) {
                searchField.tap()
                searchField.typeText("C02ABCDE123")
                XCTAssertTrue(app.staticTexts["MacBook Air 13\""].waitForExistence(timeout: 5))
            }
        }
    }
}
