import XCTest

/// Launch configuration shared by all UI test classes.
@MainActor
enum UITestLaunch {
    static func makeApp(extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetOnboarding"] + extraArgs
        return app
    }
}

@MainActor
extension XCUIElement {
    @discardableResult
    func waitAndTap(timeout: TimeInterval = 5) -> Bool {
        if waitForExistence(timeout: timeout) { tap(); return true }
        return false
    }
}

/// Mirrors the app target's AXID strings so UI tests stay locale-independent.
enum AXID {
    static let onboardingContinue = "onboarding_continue"
    static let onboardingGetStarted = "onboarding_get_started"
    static let scanButton = "scan_button"
    static let emptyStateCTA = "empty_cta"
    static let addItemButton = "add_item_button"
    static let itemNameField = "item_name_field"
    static let itemBrandField = "item_brand_field"
    static let itemSerialField = "item_serial_field"
    static let itemMerchantField = "item_merchant_field"
    static let saveItemButton = "save_item_button"
    static let deleteItemButton = "delete_item_button"
    static let manualEntryButton = "manual_entry_button"
    static let reviewMerchantField = "review_merchant_field"
    static let reviewDateField = "review_date_field"
    static let reviewTotalField = "review_total_field"
    static let reviewNameField = "review_name_field"
    static let reviewSaveButton = "review_save_button"
    static let searchField = "search_field"
    static let paywallRestoreButton = "paywall_restore"
    static let paywallDismiss = "paywall_dismiss"
    static let paywallPurchaseButton = "paywall_purchase"
    static let exportClaimPackButton = "export_claim_pack"
    static let exportCSVButton = "export_csv"
    static let settingsExportButton = "settings_export"
    static let itemClaimPackButton = "item_claim_pack"
    static let shareSheet = "share_sheet"
    static let settingsRemindersButton = "settings_reminders"
    static let reminderTimePicker = "reminder_time_picker"
    static let itemCustomReminderButton = "item_custom_reminder"
    static let saveCustomReminderButton = "save_custom_reminder"
    static let addCustomReturnLeadButton = "add_custom_return_lead"
    static let addCustomWarrantyLeadButton = "add_custom_warranty_lead"
    static let customLeadDaysField = "custom_lead_days_field"
    static let addAttachmentButton = "add_attachment_button"
    static let coverageLengthField = "coverage_length_field"
    static let addCoverageButton = "add_coverage_button"
    static let saveCoverageButton = "save_coverage_button"
    static let markServicedButton = "mark_serviced_button"
    static let editItemButton = "edit_item_button"
    static let cameraButton = "camera_button"
}
