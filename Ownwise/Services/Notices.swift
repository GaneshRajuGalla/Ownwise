import Foundation
import UserNotifications
import SwiftData

/// The notification categories and the action that can be taken from one (B4).
///
/// Reminders used to be read-only: the only thing to do with "Washer is due for service" was to open
/// the app and find the item. Carrying the coverage's id in the notification lets the notification do
/// the obvious thing itself.
///
/// `nonisolated`: everything here is identifiers and registration, called from the app delegate
/// wherever the system happens to run it.
nonisolated enum Notices {
    /// A reminder about cover that is running out.
    static let expiryCategory = "coverageExpiry"
    /// A reminder that a service plan is due — the one case where there is something to *do*.
    static let serviceCategory = "serviceDue"
    /// Records a service as done, from the notification itself.
    static let markServicedAction = "markServiced"
    /// The coverage a reminder is about, in the notification's user info.
    static let coverageKey = "coverageID"

    /// Registers the categories. Called once, at launch.
    static func registerCategories(center: UNUserNotificationCenter = .current()) {
        let markServiced = UNNotificationAction(identifier: markServicedAction,
                                                title: String(localized: "Mark serviced",
                                                              comment: "Notification action"),
                                                options: [])
        let service = UNNotificationCategory(identifier: serviceCategory,
                                             actions: [markServiced],
                                             intentIdentifiers: [],
                                             options: [])
        let expiry = UNNotificationCategory(identifier: expiryCategory,
                                            actions: [],
                                            intentIdentifiers: [],
                                            options: [])
        center.setNotificationCategories([service, expiry])
    }

    /// The coverage a reminder is about.
    ///
    /// Pulled out here, in the nonisolated context, because the payload itself (`[AnyHashable: Any]`)
    /// cannot cross to the main actor — a `UUID` can (B4).
    static func coverageID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let raw = userInfo[coverageKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }
}

/// Acts on a notification the user interacted with (B4).
@MainActor
enum NoticeActions {

    /// Marks the coverage the reminder was about as serviced.
    ///
    /// - Returns: true when the action was understood *and* the coverage was found, so the caller
    ///   only rebuilds the schedule when something actually changed.
    @discardableResult
    static func handle(actionIdentifier: String, coverageID: UUID,
                       in container: ModelContainer,
                       now: Date = .now) -> Bool {
        guard actionIdentifier == Notices.markServicedAction else { return false }
        let context = container.mainContext
        let all = (try? context.fetch(FetchDescriptor<Coverage>())) ?? []
        guard let coverage = all.first(where: { $0.id == coverageID }) else { return false }
        LibraryActions.markServiced(coverage, on: now, in: context)
        return true
    }
}
