import XCTest

final class OnboardingFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingToHomeEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetOnboarding"]
        app.launch()

        // Page 1: Scan receipts → Continue
        XCTAssertTrue(app.buttons[AXID.onboardingContinue].waitForExistence(timeout: 5))
        app.buttons[AXID.onboardingContinue].tap()
        // Page 2: Allow reminders
        XCTAssertTrue(app.buttons[AXID.onboardingContinue].waitForExistence(timeout: 5))
        app.buttons[AXID.onboardingContinue].tap()
        // Page 3: Get started
        XCTAssertTrue(app.buttons[AXID.onboardingGetStarted].waitForExistence(timeout: 5))
        app.buttons[AXID.onboardingGetStarted].tap()

        // Home empty state with scan CTA.
        XCTAssertTrue(app.buttons["Scan a receipt"].waitForExistence(timeout: 5))
    }
}
