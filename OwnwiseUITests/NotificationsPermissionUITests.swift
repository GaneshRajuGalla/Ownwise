import XCTest

/// I4: the refused-notifications state was untested because a system permission cannot be refused
/// on demand. `-forceNotificationsDenied` produces it.
@MainActor
final class NotificationsPermissionUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testRefusedNotificationsAreExplainedAndRouteToSystemSettings() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forceNotificationsDenied"])
        app.launch()

        app.tabBars.buttons[AXID.tabSettings].tap()
        let turnOn = app.buttons[AXID.settingsNotificationsButton]
        XCTAssertTrue(turnOn.waitForExistence(timeout: 5), app.debugDescription)
        // The row exists only while reminders can't reach the user; it must be tappable and lead
        // to the system setting rather than doing nothing.
        XCTAssertTrue(turnOn.isHittable)
        // The row must lead somewhere: it opens this app's page in system Settings, which means the
        // app leaves the foreground. (No text matching — the label is localisable. See I5.)
        turnOn.tap()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 8),
                      "the row opens system Settings instead of doing nothing")
    }

    /// The default test build has notifications allowed, so the warning row must NOT be there.
    func testAllowedNotificationsDoNotShowTheWarning() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding"])
        app.launch()

        app.tabBars.buttons[AXID.tabSettings].tap()
        XCTAssertTrue(app.buttons[AXID.settingsExportButton].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[AXID.settingsNotificationsButton].exists,
                       "no warning while reminders can reach the user")
    }
}
