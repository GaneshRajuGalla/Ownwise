import XCTest

@MainActor
final class RemindersFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testFreeUserCustomizeRemindersOpensPaywall() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forceFree"])
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons[AXID.settingsRemindersButton].waitForExistence(timeout: 5))
        // Badged before the tap, so the paywall is never a surprise.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: AXID.proBadge).count, 2)
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
        // Pro users see plain rows — no badge.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: AXID.proBadge).count, 0)
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
        scrollToElement(add, in: app)
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
        scrollToElement(add, in: app)
        add.tap()
        XCTAssertTrue(app.buttons[AXID.saveCustomReminderButton].waitForExistence(timeout: 5))
        app.buttons[AXID.saveCustomReminderButton].tap()
        // After saving, the card offers to change the reminder instead of adding one.
        XCTAssertTrue(app.buttons[AXID.itemCustomReminderButton].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Change reminder"].exists || app.buttons["Change reminder"].exists)
    }

    /// The item screen is a SwiftUI ScrollView, which doesn't always auto-scroll
    /// an element into view before a tap; nudge it until it's tappable.
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 4) {
        for _ in 0..<attempts where !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
    }

    /// End-to-end for the reminder picker: choose a preset while adding an item,
    /// and confirm the choice survives into the store and back out again.
    func testPresetChosenWhileAddingAnItemPersists() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forcePro"])
        app.launch()

        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.buttons[AXID.addItemButton].waitAndTap())
        XCTAssertTrue(app.textFields[AXID.itemNameField].waitForExistence(timeout: 5))
        app.textFields[AXID.itemNameField].tap()
        app.textFields[AXID.itemNameField].typeText("Coffee machine")

        // A warranty length reveals the reminder section.
        let warranty = app.textFields["Warranty (months)"]
        XCTAssertTrue(warranty.waitForExistence(timeout: 5))
        warranty.tap()
        warranty.typeText("12")

        let threeMonths = app.buttons[AXID.reminderPresetPrefix + "90"]
        XCTAssertTrue(threeMonths.waitForExistence(timeout: 5), app.debugDescription)
        scrollToElement(threeMonths, in: app)
        threeMonths.tap()

        let save = app.buttons[AXID.saveItemButton]
        scrollToElement(save, in: app)
        XCTAssertTrue(save.waitAndTap())

        // Open the saved item and step into its reminder editor.
        let row = app.staticTexts["Coffee machine"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let coverageReminder = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AXID.editCoverageReminderPrefix)
        ).firstMatch
        XCTAssertTrue(coverageReminder.waitForExistence(timeout: 5), app.debugDescription)
        scrollToElement(coverageReminder, in: app)
        coverageReminder.tap()

        // "Use default" only exists when an override is stored, so this proves
        // the tap in the add-item form round-tripped through SwiftData.
        XCTAssertTrue(app.buttons[AXID.resetReminderLeadsButton].waitForExistence(timeout: 5))
    }
}
