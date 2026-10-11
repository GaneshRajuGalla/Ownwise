import XCTest

@MainActor
final class RemindersFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testFreeUserCustomizeRemindersOpensPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons[AXID.settingsRemindersButton].waitForExistence(timeout: 5))
        app.buttons[AXID.settingsRemindersButton].tap()
        XCTAssertTrue(app.buttons[AXID.paywallPurchaseButton].waitForExistence(timeout: 5))
        app.buttons[AXID.paywallDismiss].tap()
        XCTAssertFalse(app.datePickers[AXID.reminderTimePicker].waitForExistence(timeout: 2))
    }

    func testProUserCanCustomizeReminders() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forcePro"])
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons[AXID.settingsRemindersButton].waitForExistence(timeout: 5))
        app.buttons[AXID.settingsRemindersButton].tap()
        XCTAssertTrue(app.datePickers[AXID.reminderTimePicker].waitForExistence(timeout: 5))
    }

    func testFreeUserCustomItemReminderOpensPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Items"].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let add = app.buttons[AXID.itemCustomReminderButton]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.buttons[AXID.paywallPurchaseButton].waitForExistence(timeout: 5))
    }

    func testProUserSetsCustomItemReminder() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-seedSampleData", "-forcePro"])
        app.launch()
        app.tabBars.buttons["Items"].tap()
        let row = app.staticTexts["Washer"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let add = app.buttons[AXID.itemCustomReminderButton]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.buttons[AXID.saveCustomReminderButton].waitForExistence(timeout: 5))
        app.buttons[AXID.saveCustomReminderButton].tap()
        // After saving, the card offers to change the reminder instead of adding one.
        XCTAssertTrue(app.buttons[AXID.itemCustomReminderButton].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Change reminder"].exists || app.buttons["Change reminder"].exists)
    }
}
