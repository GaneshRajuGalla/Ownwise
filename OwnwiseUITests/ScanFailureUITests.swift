import XCTest

/// C4: a scan that cannot proceed says why and offers a way forward, instead of dropping the user
/// back on the picker with no explanation.
@MainActor
final class ScanFailureUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func openScan(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons[AXID.scanButton].waitForExistence(timeout: 5))
        app.buttons[AXID.scanButton].tap()
        XCTAssertTrue(app.buttons[AXID.cameraButton].waitForExistence(timeout: 5))
        app.buttons[AXID.cameraButton].tap()
    }

    /// The forced state stands in for "this device has no document scanner" and for a refused
    /// camera permission, so the test behaves the same on a simulator and on a phone.
    func testUnavailableCameraExplainsItselfAndOffersManualEntry() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forcePro", "-forceScanUnavailable"])
        app.launch()
        openScan(app)

        let problem = app.descendants(matching: .any)[AXID.scanProblem]
        XCTAssertTrue(problem.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons[AXID.scanProblemPrimary].exists)
        XCTAssertTrue(app.buttons[AXID.scanProblemSecondary].exists)

        // The secondary action is the escape hatch: it must land on the review form, empty but
        // usable, so a receipt can still be entered by hand.
        app.buttons[AXID.scanProblemSecondary].tap()
        XCTAssertTrue(app.textFields[AXID.reviewNameField].waitForExistence(timeout: 5))
    }

    /// A scan that reads no text at all must not open an empty review form as if it had worked.
    func testUnreadableReceiptStopsInsteadOfOpeningABlankDraft() throws {
        let app = UITestLaunch.makeApp(extraArgs: ["-skipOnboarding", "-forcePro", "-forceScanUnreadable"])
        app.launch()
        openScan(app)

        let problem = app.descendants(matching: .any)[AXID.scanProblem]
        XCTAssertTrue(problem.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.textFields[AXID.reviewNameField].exists)

        app.buttons[AXID.scanProblemSecondary].tap()
        XCTAssertTrue(app.textFields[AXID.reviewNameField].waitForExistence(timeout: 5))
    }
}
