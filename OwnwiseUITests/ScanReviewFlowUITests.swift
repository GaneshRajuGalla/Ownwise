import XCTest

final class ScanReviewFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testScanFixtureReviewSave() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-fixtureReceipt", "us"])
        app.launch()

        XCTAssertTrue(app.buttons[AXID.scanButton].waitForExistence(timeout: 5))
        app.buttons[AXID.scanButton].tap()

        XCTAssertTrue(app.buttons[AXID.cameraButton].waitForExistence(timeout: 5))
        app.buttons[AXID.cameraButton].tap()

        // Review shows prefilled merchant/date/total from the fixture.
        XCTAssertTrue(app.textFields[AXID.reviewMerchantField].waitForExistence(timeout: 5))
        let merchant = app.textFields[AXID.reviewMerchantField]
        XCTAssertEqual(merchant.value as? String, "Best Buy")
        let total = app.textFields[AXID.reviewTotalField]
        XCTAssertEqual(total.value as? String, "1299.50")
        app.collectionViews.firstMatch.swipeUp()
        let save = app.buttons[AXID.reviewSaveButton].exists ? app.buttons[AXID.reviewSaveButton] : app.buttons["Save item"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), app.debugDescription)
        save.tap()
    }
}
