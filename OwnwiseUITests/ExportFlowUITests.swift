import XCTest

@MainActor
final class ExportFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func openExport(_ app: XCUIApplication) {
        app.tabBars.buttons[AXID.tabSettings].tap()
        XCTAssertTrue(app.buttons[AXID.settingsExportButton].waitForExistence(timeout: 5))
        app.buttons[AXID.settingsExportButton].tap()
    }

    private func firstClaimPack(_ app: XCUIApplication) -> XCUIElement {
        // One identifier per item, so a test can name the row it means.
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AXID.exportClaimPackPrefix)).firstMatch
    }

    private func assertShareSheet(_ app: XCUIApplication) {
        let sheet = app.descendants(matching: .any)[AXID.shareSheet]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10) || app.otherElements["ActivityListView"].waitForExistence(timeout: 2))
    }

    /// Raw export and backups are free: a paywall between a user and their own data is exactly
    /// what the app promises never to do.
    func testFreeUserReachesCSVAndBackupWithoutAPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        openExport(app)

        XCTAssertTrue(app.buttons[AXID.exportCSVButton].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AXID.exportBackupButton].exists)
        XCTAssertTrue(app.buttons[AXID.exportRestoreButton].exists)
        XCTAssertFalse(app.buttons[AXID.paywallRestoreButton].exists)

        app.buttons[AXID.exportCSVButton].tap()
        assertShareSheet(app)
    }

    func testFreeUserBackupProducesAFile() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        openExport(app)

        XCTAssertTrue(app.buttons[AXID.exportBackupButton].waitForExistence(timeout: 5))
        app.buttons[AXID.exportBackupButton].tap()
        assertShareSheet(app)
    }

    /// The Claim Pack is watermarked rather than blocked, so the payoff is visible before paying.
    func testFreeUserClaimPackIsAPreviewNotADeadEnd() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        openExport(app)

        let claim = firstClaimPack(app)
        XCTAssertTrue(claim.waitForExistence(timeout: 5))
        claim.tap()
        assertShareSheet(app)
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
        let claim = firstClaimPack(app)
        XCTAssertTrue(claim.waitForExistence(timeout: 5))
        claim.tap()
        assertShareSheet(app)
    }

    func testProSeesNoProBadgeInExport() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forcePro"])
        app.launch()
        openExport(app)
        XCTAssertTrue(app.buttons[AXID.exportCSVButton].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: AXID.proBadge).count, 0)
    }

    func testItemDetailClaimPack() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forcePro"])
        app.launch()
        app.tabBars.buttons[AXID.tabItems].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons[AXID.itemClaimPackButton].waitForExistence(timeout: 5))
        app.buttons[AXID.itemClaimPackButton].tap()
        assertShareSheet(app)
    }

    /// The detail screen behaves like the Export screen: a preview, not the paywall.
    func testItemDetailClaimPackForFreeUserIsAPreview() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        app.tabBars.buttons[AXID.tabItems].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons[AXID.itemClaimPackButton].waitForExistence(timeout: 5))
        app.buttons[AXID.itemClaimPackButton].tap()
        assertShareSheet(app)
        XCTAssertFalse(app.buttons[AXID.paywallRestoreButton].exists)
    }
}
