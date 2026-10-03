import XCTest

final class ExportFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testExportShareSheetAppears() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData"])
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let export = app.staticTexts["Export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        XCTAssertTrue(app.buttons[AXID.exportCSVButton].waitForExistence(timeout: 5))
        app.buttons[AXID.exportCSVButton].tap()
        // Share link appears after export.
        let share = app.buttons["Share CSV"].exists ? app.buttons["Share CSV"] : app.staticTexts["Share CSV"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
    }
}
