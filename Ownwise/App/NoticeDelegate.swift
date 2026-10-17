import Foundation
import UIKit
import UserNotifications
import SwiftData

/// The app delegate, which exists only for notifications (B4).
///
/// SwiftUI has no hook for registering notification categories at launch or for responding to an
/// action on a notification, so there is a small `UIApplicationDelegate` for exactly those two jobs.
/// It holds no state: the system may recreate it whenever it likes, and everything it needs it reads
/// from `Persistence` and `Notices`.
final class NoticeDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Notices.registerCategories()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// A reminder that arrives while the app is open is still worth seeing; the default is silence.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Runs when the user picks an action — a plain tap just opens the app, and does not come here.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        // Only Sendable values may cross to the main actor, so the id is read out here.
        guard let coverageID = Notices.coverageID(from: response.notification.request.content.userInfo) else { return }
        await MainActor.run { apply(action: action, coverageID: coverageID) }
    }

    @MainActor
    private func apply(action: String, coverageID: UUID) {
        let container = Persistence.sharedContainer
        guard NoticeActions.handle(actionIdentifier: action, coverageID: coverageID, in: container) else { return }
        // A background action does not bring the app forward, so the schedule is rebuilt here rather
        // than waiting for a scene phase change that may never come.
        let scheduler = ReminderScheduler()
        Task {
            scheduler.configure(isPro: await StoreEntitlement.isPro())
            await scheduler.rescheduleFromContext(container.mainContext)
        }
    }
}
