import XCTest

final class PaywallFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPaywallShowsAndRestores() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forceFree"])
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let upgrade = app.buttons["Upgrade to Pro"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        upgrade.tap()
        XCTAssertTrue(app.buttons[AXID.paywallRestoreButton].waitForExistence(timeout: 5))
        app.buttons["paywall_restore"].firstMatch.tap()
        app.buttons[AXID.paywallDismiss].tap()
    }
}
