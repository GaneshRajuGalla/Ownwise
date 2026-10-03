import Foundation

/// Stable accessibility identifiers shared in spirit with the UI test target
/// (UI tests match by these strings, never by visible text).
enum AXID {
    static let scanButton = "scan_button"
    static let emptyStateCTA = "empty_cta"
    static let tabHome = "tab_home"
    static let tabItems = "tab_items"
    static let tabSettings = "tab_settings"
    static let tabSearch = "tab_search"

    static let addItemButton = "add_item_button"
    static let itemNameField = "item_name_field"
    static let itemBrandField = "item_brand_field"
    static let itemSerialField = "item_serial_field"
    static let itemMerchantField = "item_merchant_field"
    static let saveItemButton = "save_item_button"
    static let cancelButton = "cancel_button"
    static let deleteItemButton = "delete_item_button"
    static let editItemButton = "edit_item_button"

    static let manualEntryButton = "manual_entry_button"
    static let cameraButton = "camera_button"
    static let photosButton = "photos_button"
    static let filesButton = "files_button"

    static let reviewMerchantField = "review_merchant_field"
    static let reviewDateField = "review_date_field"
    static let reviewTotalField = "review_total_field"
    static let reviewNameField = "review_name_field"
    static let reviewSaveButton = "review_save_button"

    static let searchField = "search_field"
    static let filterActive = "filter_active"
    static let filterExpired = "filter_expired"

    static let paywallPurchaseButton = "paywall_purchase"
    static let paywallRestoreButton = "paywall_restore"
    static let paywallDismiss = "paywall_dismiss"

    static let exportClaimPackButton = "export_claim_pack"
    static let exportCSVButton = "export_csv"

    static let onboardingContinue = "onboarding_continue"
    static let onboardingGetStarted = "onboarding_get_started"
    static let unlockButton = "unlock_button"
    static let needsAttentionList = "needs_attention_list"
    static let itemRowPrefix = "item_row_"
    static let coverageKindPicker = "coverage_kind_picker"
    static let addCoverageButton = "add_coverage_button"
    static let homeScanCTA = "home_scan_cta"
}
