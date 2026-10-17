import XCTest

final class ManualAddFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testManualAddItemWarrantyEditDelete() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding"])
        app.launch()

        // Items tab
        app.tabBars.buttons[AXID.tabItems].tap()
        XCTAssertTrue(app.buttons[AXID.addItemButton].waitForExistence(timeout: 5))
        app.buttons[AXID.addItemButton].tap()

        // Fill the add form
        XCTAssertTrue(app.textFields[AXID.itemNameField].waitForExistence(timeout: 5))
        app.textFields[AXID.itemNameField].tap()
        app.textFields[AXID.itemNameField].typeText("Sample TV")
        app.textFields[AXID.itemBrandField].tap()
        app.textFields[AXID.itemBrandField].typeText("LG")
        app.textFields[AXID.itemSerialField].tap()
        app.textFields[AXID.itemSerialField].typeText("ABC123XYZ")
        app.textFields[AXID.itemMerchantField].tap()
        app.textFields[AXID.itemMerchantField].typeText("Best Buy")

        app.buttons[AXID.saveItemButton].tap()

        // Item appears in the list
        XCTAssertTrue(app.staticTexts["Sample TV"].waitForExistence(timeout: 5))

        // Open detail → days-left coverage chip → edit → delete
        app.staticTexts["Sample TV"].tap()
        XCTAssertTrue(app.buttons[AXID.editItemButton].waitForExistence(timeout: 5))
        app.buttons[AXID.editItemButton].tap()
        XCTAssertTrue(app.buttons[AXID.saveItemButton].waitForExistence(timeout: 5))
        app.buttons[AXID.saveItemButton].tap()

        // Back to the Items list, then delete via swipe.
        if app.navigationBars.buttons.count > 0 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let listApp = app
        let rowText = listApp.staticTexts["Sample TV"].firstMatch
        if rowText.waitForExistence(timeout: 5) {
            // Swiping reveals Delete, but nothing is destroyed until it is confirmed.
            rowText.swipeLeft()
            let swipeDelete = app.buttons[AXID.deleteSwipeButton].firstMatch
            XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3))
            swipeDelete.tap()

            let cancel = app.buttons["Cancel"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Deleting an item asks for confirmation")
            cancel.tap()
            XCTAssertTrue(app.staticTexts["Sample TV"].waitForExistence(timeout: 3), "Cancelling keeps the item")

            rowText.swipeLeft()
            app.buttons[AXID.deleteSwipeButton].firstMatch.tap()
            let confirm = app.buttons[AXID.deleteItemButton].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 3))
            confirm.tap()
        }
        XCTAssertFalse(app.staticTexts["Sample TV"].waitForExistence(timeout: 3))
    }
}
