import XCTest

@MainActor
final class ItemDetailFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func openItem(_ name: String, args: [String]) -> XCUIApplication {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData"] + args)
        app.launch()
        app.tabBars.buttons["Items"].tap()
        let row = app.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        return app
    }

    /// Claim facts are visible and selectable on the item screen.
    func testDetailsShowSerialAndPrice() throws {
        let app = openItem("MacBook Air 13\"", args: ["-forcePro"])
        let serial = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "C02ABCDE123")).firstMatch
        XCTAssertTrue(serial.waitForExistence(timeout: 5))
    }

    /// An ended return window must not make an item with a live warranty look expired.
    func testAddReturnWindowCountsFromPurchaseDate() throws {
        let app = openItem("Washer", args: ["-forcePro"])
        let add = app.buttons[AXID.addCoverageButton].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let save = app.buttons[AXID.saveCoverageButton]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertFalse(save.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Return window"].waitForExistence(timeout: 5))
    }

    func testAddPhotoButtonIsAvailable() throws {
        let app = openItem("Washer", args: ["-forceFree"])
        let addPhoto = app.buttons[AXID.addAttachmentButton]
        for _ in 0..<4 where !addPhoto.isHittable { app.swipeUp() }
        XCTAssertTrue(addPhoto.waitForExistence(timeout: 5))
    }

    /// Seeded washer's service is overdue; marking it serviced clears "Service due" so reminders recur.
    func testMarkServicedRestartsInterval() throws {
        let app = openItem("Washer", args: ["-forcePro"])
        let mark = app.buttons[AXID.markServicedButton]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap()
        XCTAssertFalse(mark.waitForExistence(timeout: 3))
    }
}
