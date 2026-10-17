import XCTest

/// I1: this test used to bury every assertion inside `if` guards, so it passed with zero assertions
/// whenever the tab or the field never appeared. It now asserts unconditionally — if the app does
/// not show what it should, this fails.
@MainActor
final class SearchFilterUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func openSearch(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.buttons[AXID.tabSearch].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons[AXID.tabSearch].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), app.debugDescription)
        return field
    }

    func testSearchFindsAnItemBySerialAndFiltersTheRestOut() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData"])
        app.launch()

        let field = openSearch(app)
        // With no query yet, everything is listed.
        XCTAssertTrue(app.staticTexts["MacBook Air 13\""].waitForExistence(timeout: 5))

        field.tap()
        field.typeText("C02ABCDE123")
        // Wait for the list to actually filter before asserting what is left, so the match cannot be
        // satisfied by the pre-filter render.
        XCTAssertTrue(app.staticTexts["Washer"].waitForNonExistence(timeout: 5),
                      "typing a serial filters the other items out")
        XCTAssertTrue(app.staticTexts["MacBook Air 13\""].exists, "the serial on the receipt finds the item")
    }

    func testSearchMatchesTheMerchantAndAnUnmatchedQueryShowsNoRows() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData"])
        app.launch()

        let field = openSearch(app)
        field.tap()
        field.typeText("Best Buy")
        XCTAssertTrue(app.staticTexts["Washer"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["55\" OLED TV"].exists, "the merchant typed on the item is searchable")
        XCTAssertFalse(app.staticTexts["MacBook Air 13\""].exists)

        field.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["55\" OLED TV"].waitForNonExistence(timeout: 5),
                      "no match means no rows")
    }
}
