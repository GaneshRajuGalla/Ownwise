import XCTest

@MainActor
final class ExportFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func openExport(_ app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons[AXID.settingsExportButton].waitForExistence(timeout: 5))
        app.buttons[AXID.settingsExportButton].tap()
    }

    private func assertShareSheet(_ app: XCUIApplication) {
        let sheet = app.descendants(matching: .any)[AXID.shareSheet]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10) || app.otherElements["ActivityListView"].waitForExistence(timeout: 2))
    }

    func testFreeUserExportOpensPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        openExport(app)
        XCTAssertTrue(app.buttons[AXID.paywallRestoreButton].waitForExistence(timeout: 5))
        app.buttons[AXID.paywallDismiss].tap()
        XCTAssertFalse(app.buttons[AXID.exportCSVButton].waitForExistence(timeout: 2))
    }

    func testProCSVShareSheetAppears() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forcePro"])
        app.launch()
        openExport(app)
        XCTAssertTrue(app.buttons[AXID.exportCSVButton].waitForExistence(timeout: 5))
        app.buttons[AXID.exportCSVButton].tap()
        assertShareSheet(app)
    }

    func testProClaimPackShareSheetAppears() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forcePro"])
        app.launch()
        openExport(app)
        let claim = app.buttons[AXID.exportClaimPackButton].firstMatch
        XCTAssertTrue(claim.waitForExistence(timeout: 5))
        claim.tap()
        assertShareSheet(app)
    }

    func testItemDetailClaimPack() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forcePro"])
        app.launch()
        app.tabBars.buttons["Items"].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons[AXID.itemClaimPackButton].waitForExistence(timeout: 5))
        app.buttons[AXID.itemClaimPackButton].tap()
        assertShareSheet(app)
    }

    func testItemDetailClaimPackFreeShowsPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Items"].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons[AXID.itemClaimPackButton].waitForExistence(timeout: 5))
        app.buttons[AXID.itemClaimPackButton].tap()
        XCTAssertTrue(app.buttons[AXID.paywallRestoreButton].waitForExistence(timeout: 5))
    }
}
