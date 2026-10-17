import XCTest

/// Pins what is free and what is Pro, so a gating regression is a failing test rather than a
/// surprise for someone who has already decided to trust the app with their receipts.
@MainActor
final class GatingUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testFreeUserCanOpenTheCoverageEditorWithoutAPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Items"].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.buttons[AXID.addCoverageButton].waitForExistence(timeout: 5))
        app.buttons[AXID.addCoverageButton].tap()

        // A coverage kind is a data type, not an advanced feature (D1).
        XCTAssertTrue(app.descendants(matching: .any)[AXID.coverageKindPicker].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[AXID.paywallPurchaseButton].exists)
    }

    func testFreeUserReachesExportWithoutAPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.buttons[AXID.settingsExportButton].waitForExistence(timeout: 5))
        app.buttons[AXID.settingsExportButton].tap()

        XCTAssertTrue(app.buttons[AXID.exportBackupButton].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[AXID.paywallRestoreButton].exists)
    }

    /// Custom reminder timing is the paid feature, so it must still ask.
    func testFreeUserGetsThePaywallForCustomReminders() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.buttons[AXID.settingsRemindersButton].waitForExistence(timeout: 5))
        app.buttons[AXID.settingsRemindersButton].tap()

        XCTAssertTrue(app.buttons[AXID.paywallPurchaseButton].waitForExistence(timeout: 5))
    }
}
